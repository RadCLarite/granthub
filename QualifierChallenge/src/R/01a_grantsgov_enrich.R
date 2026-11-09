# 01a_grantsgov_enrich.R — current status for every opportunity, and full
# announcements (NOFOs) for the candidate set, from the free Grants.gov API.
# Every response is cached to disk with its access date; a second run makes no
# network calls. Requires 00_config.R and 01_load_clean.R (for `grants`).
#
# Run standalone (slow on first run, ~30 min):  Rscript src/R/01a_grantsgov_enrich.R

suppressPackageStartupMessages({ library(httr2); library(jsonlite) })

safe_name <- function(x) str_replace_all(x, "[^A-Za-z0-9._-]", "_")

write_accessed <- function(path) {
  writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), paste0(path, ".accessed"))
}

read_accessed <- function(path) {
  f <- paste0(path, ".accessed")
  if (file.exists(f)) readLines(f, n = 1) else NA_character_
}

gg_post <- function(endpoint, body) {
  Sys.sleep(GRANTSGOV_SLEEP_SEC)
  request(paste0(GRANTSGOV_API_BASE, "/", endpoint)) |>
    req_body_json(body) |>
    req_retry(max_tries = 4, backoff = ~ 5) |>
    req_timeout(60) |>
    req_perform() |>
    resp_body_string()
}

# Search by opportunity number across all statuses; cached raw JSON text.
gg_search_cached <- function(number) {
  path <- file.path(DIR_CACHE_GRANTS, "search", paste0(safe_name(number), ".json"))
  if (!file.exists(path)) {
    txt <- gg_post("search2", list(keyword = number, rows = 25,
                                   oppStatuses = "forecasted|posted|closed|archived"))
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    writeLines(txt, path); write_accessed(path)
  }
  path
}

gg_fetch_cached <- function(legacy_id) {
  path <- file.path(DIR_CACHE_GRANTS, "fetch", paste0(legacy_id, ".json"))
  if (!file.exists(path)) {
    txt <- gg_post("fetchOpportunity", list(opportunityId = as.integer(legacy_id)))
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    writeLines(txt, path); write_accessed(path)
  }
  path
}

parse_search_hit <- function(path, number) {
  hits <- fromJSON(path, simplifyVector = FALSE)$data$oppHits
  hit <- keep(hits, ~ toupper(.x$number) == toupper(number))
  if (length(hit) == 0) {
    return(tibble(legacy_id = NA_character_, status_now = NA_character_,
                  close_date_now = as.Date(NA), status_checked = read_accessed(path)))
  }
  h <- hit[[1]]
  tibble(legacy_id = as.character(h$id),
         status_now = h$oppStatus %||% NA_character_,
         close_date_now = as.Date(h$closeDate %||% NA_character_, "%m/%d/%Y"),
         status_checked = read_accessed(path))
}

parse_attachments <- function(path) {
  d <- fromJSON(path, simplifyVector = FALSE)$data
  folders <- d$synopsisAttachmentFolders %||% list()
  map_dfr(folders, function(f) {
    map_dfr(f$synopsisAttachments %||% list(), function(a) tibble(
      folder_type = f$folderType %||% NA_character_,
      attachment_id = as.character(a$id),
      file_name = a$fileName %||% NA_character_,
      mime_type = a$mimeType %||% NA_character_,
      bytes = as.numeric(a$fileLobSize %||% NA)))
  })
}

# Candidate set for full-announcement retrieval: state-eligible, not NIH, and
# either posted and not closed at the pull date, or forecasted.
is_nofo_candidate <- function(g) {
  g$state_eligible & !g$is_nih &
    ((g$status_group == "Posted" & (is.na(g$close_date) | g$close_date >= PULL_DATE)) |
       g$status_group == "Forecasted")
}

pick_nofo_files <- function(att) {
  docs <- att |>
    filter(str_detect(coalesce(mime_type, ""), "pdf|word|msword") |
             str_detect(coalesce(file_name, ""), regex("\\.(pdf|docx?)$", ignore_case = TRUE)),
           coalesce(bytes, 0) <= NOFO_MAX_BYTES)
  full <- docs |> filter(folder_type == "Full Announcement")
  if (nrow(full) > 0) full else docs
}

download_nofo <- function(number, att_row) {
  dest <- file.path(DIR_RAW_NOFO, safe_name(number),
                    paste0(att_row$attachment_id, "_", safe_name(att_row$file_name)))
  if (!file.exists(dest)) {
    Sys.sleep(GRANTSGOV_SLEEP_SEC)
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
    ok <- tryCatch({
      request(paste0(GRANTSGOV_ATT_BASE, "/", att_row$attachment_id)) |>
        req_retry(max_tries = 3, backoff = ~ 5) |> req_timeout(120) |>
        req_perform(path = dest)
      TRUE
    }, error = function(e) { message("NOFO download failed: ", number, " ", conditionMessage(e)); FALSE })
    if (!ok) { unlink(dest); return(NA_character_) }
    write_accessed(dest)
  }
  dest
}

extract_text <- function(path) {
  if (is.na(path) || !file.exists(path)) return(NA_character_)
  if (str_detect(path, regex("\\.pdf$", ignore_case = TRUE))) {
    txt <- tryCatch(paste(pdftools::pdf_text(path), collapse = "\n\f"), error = function(e) NA_character_)
  } else if (str_detect(path, regex("\\.docx$", ignore_case = TRUE))) {
    txt <- tryCatch({
      x <- xml2::read_xml(unz(path, "word/document.xml"))
      paste(xml2::xml_text(xml2::xml_find_all(x, "//w:p")), collapse = "\n")
    }, error = function(e) NA_character_)
  } else {
    txt <- NA_character_
  }
  txt
}

run_grantsgov_enrichment <- function(g) {
  message("Searching Grants.gov for ", nrow(g), " opportunity numbers (cached after first run)")
  status <- map2_dfr(g$opportunity_number, seq_len(nrow(g)), function(num, i) {
    if (i %% 100 == 0) message("  search ", i, "/", nrow(g))
    tryCatch(parse_search_hit(gg_search_cached(num), num),
             error = function(e) { message("search failed: ", num, " ", conditionMessage(e))
               tibble(legacy_id = NA_character_, status_now = NA_character_,
                      close_date_now = as.Date(NA), status_checked = NA_character_) })
  }) |> mutate(opportunity_number = g$opportunity_number, .before = 1)

  cand <- g |> mutate(nofo_candidate = is_nofo_candidate(g)) |>
    filter(nofo_candidate) |> select(opportunity_number) |>
    left_join(status, by = "opportunity_number") |> filter(!is.na(legacy_id))
  message("NOFO candidate set with a Grants.gov match: ", nrow(cand))

  nofo <- map2_dfr(cand$opportunity_number, cand$legacy_id, function(num, id) {
    att <- tryCatch(parse_attachments(gg_fetch_cached(id)), error = function(e) tibble())
    files <- if (nrow(att) > 0) pick_nofo_files(att) else att
    if (nrow(files) == 0) {
      return(tibble(opportunity_number = num, n_attachments = nrow(att),
                    nofo_files = 0L, nofo_chars = 0L, nofo_text = NA_character_))
    }
    paths <- map_chr(seq_len(nrow(files)), ~ download_nofo(num, files[.x, ]))
    texts <- map_chr(paths, extract_text)
    txt <- paste(na.omit(texts), collapse = "\n\n")
    tibble(opportunity_number = num, n_attachments = nrow(att),
           nofo_files = sum(!is.na(paths)), nofo_chars = nchar(txt),
           nofo_text = if (nzchar(txt)) txt else NA_character_)
  })

  list(status = status, nofo = nofo)
}

# ---- Standalone run -------------------------------------------------------------
if (sys.nframe() == 0L) {
  here::i_am("src/R/01a_grantsgov_enrich.R")
  source(here::here("src", "R", "00_config.R"))
  source(here::here("src", "R", "01_load_clean.R"))
  enrich <- run_grantsgov_enrichment(grants)
  dir.create(DIR_PROCESSED, showWarnings = FALSE, recursive = TRUE)
  saveRDS(enrich, file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))
  message("Status: ", paste(names(table(enrich$status$status_now, useNA = "ifany")),
                            table(enrich$status$status_now, useNA = "ifany"), collapse = ", "))
  message("NOFO text retrieved for ", sum(!is.na(enrich$nofo$nofo_text)), " of ",
          nrow(enrich$nofo), " candidates")
}

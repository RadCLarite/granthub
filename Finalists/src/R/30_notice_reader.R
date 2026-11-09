# 30_notice_reader.R: advisory notice reader (decision 9).
# For "ask" items in the payload, an LLM reads the notice's eligibility text and returns a label
# (lead, partner, not_eligible, unclear) plus an exact quote. A label whose quote is not found in
# the text is thrown out (falls back to "unclear"). It never hides a row and never sets a tier.
#
# Safe by default: with no flags it reads the cache only and makes NO model call.
#   Live calls need:  NOTICE_READER_LIVE=yes  plus  AOAI_ENDPOINT and AOAI_KEY (env vars, never in files).
#   Calls per run are capped by NOTICE_MAX_CALLS. Every response is cached before use.
# Output: data/processed/notice_reader.csv (opp_id, reader_label, reader_quote, quote_ok, cached).
# It does not edit payload.json; Kent's build merges these columns (reader_label, reader_quote).
# Run from Finalists/src:  Rscript R/30_notice_reader.R

suppressPackageStartupMessages({ library(here); library(dplyr); library(stringr); library(readr); library(jsonlite) })
here::i_am("src/R/30_notice_reader.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_llm.R"))   # normalize_text(), build_prompt()

# TODO move to 00_config.R
NOTICE_MAX_CALLS   <- 60L                                  # hard cap on live calls per run
NOTICE_DEPLOYMENT  <- "gpt-4o-mini"                        # Azure OpenAI deployment name
NOTICE_PROMPT_VER  <- "n1"                                 # bump to invalidate cached labels
NOTICE_API_VERSION <- "2024-06-01"
NOTICE_LEVELS      <- c("lead", "partner", "not_eligible", "unclear")   # last = no support
NOTICE_QUESTION    <- paste("Can a North Carolina state agency apply as the lead applicant?",
  "lead = the text says state agencies (or state governments) may apply;",
  "partner = only as a partner, subrecipient or through another applicant;",
  "not_eligible = the text excludes state agencies;",
  "unclear = the text does not say.")
NOTICE_MAX_TEXT    <- 6000L                                # characters sent per item
DIR_CACHE_NOTICE   <- here::here("data", "cache", "llm_notice")

aoai_chat <- function(prompt) {
  ep <- Sys.getenv("AOAI_ENDPOINT"); key <- Sys.getenv("AOAI_KEY")
  if (!nzchar(ep) || !nzchar(key)) stop("Set AOAI_ENDPOINT and AOAI_KEY in the environment (not in a file).")
  url <- sprintf("%s/openai/deployments/%s/chat/completions?api-version=%s",
                 sub("/$", "", ep), NOTICE_DEPLOYMENT, NOTICE_API_VERSION)
  resp <- httr2::request(url) |> httr2::req_headers(`api-key` = key) |> httr2::req_timeout(60) |>
    httr2::req_retry(max_tries = 5) |>   # waits and retries on 429 (low capacity deployment)
    httr2::req_body_json(list(temperature = 0, seed = LLM_SEED, max_tokens = 200,
      response_format = list(type = "json_object"),
      messages = list(list(role = "user", content = prompt)))) |>
    httr2::req_perform() |> httr2::resp_body_json()
  resp$choices[[1]]$message$content
}

# Label one text. `live` gates network use; `calls` is an environment counting live calls.
read_notice <- function(text, live = FALSE, calls = new.env(), chat_fn = aoai_chat) {
  none <- NOTICE_LEVELS[length(NOTICE_LEVELS)]
  text <- substr(normalize_text(text), 1, NOTICE_MAX_TEXT)
  prompt <- build_prompt(NOTICE_QUESTION, NOTICE_LEVELS, text)
  key <- digest::digest(list(NOTICE_DEPLOYMENT, NOTICE_PROMPT_VER, prompt), algo = "sha256")
  path <- file.path(DIR_CACHE_NOTICE, paste0(key, ".json"))
  cached <- file.exists(path)
  if (!cached) {
    n <- if (is.null(calls$n)) 0L else calls$n
    if (!live || n >= NOTICE_MAX_CALLS)
      return(tibble::tibble(reader_label = NA_character_, reader_quote = NA_character_,
                            quote_ok = NA, cached = FALSE, skipped = TRUE))
    dir.create(DIR_CACHE_NOTICE, showWarnings = FALSE, recursive = TRUE)
    out <- chat_fn(prompt)
    writeLines(out, path, useBytes = TRUE)       # cache before use
    calls$n <- n + 1L
  }
  raw <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(e) list(label = NA, evidence = ""))
  label <- as.character(parsed$label %||% NA); ev <- as.character(parsed$evidence %||% "")
  ok <- !is.na(label) && label %in% NOTICE_LEVELS &&
    (label == none || (nzchar(ev) && str_detect(text, fixed(normalize_text(ev), ignore_case = TRUE))))
  tibble::tibble(reader_label = if (ok) label else none,
                 reader_quote = if (ok && label != none) normalize_text(ev) else NA_character_,
                 quote_ok = ok, cached = cached, skipped = FALSE)
}

run_notice_reader <- function(payload_path = here::here("data", "processed", "payload.json"), extract_path = here::here("data", "processed", "grantsgov_extract.csv"),
                              live = identical(Sys.getenv("NOTICE_READER_LIVE"), "yes"), chat_fn = aoai_chat) {
  pl <- jsonlite::read_json(payload_path, simplifyVector = TRUE)$rows
  ask <- pl |> filter(eligibility == "ask") |> arrange(desc(in_top10), rank) |> distinct(opp_id)   # Top 10 rows first, so the call cap covers what users see
  ex <- read_csv(extract_path, col_types = cols(.default = "c"), show_col_types = FALSE) |>
    distinct(opp_id, .keep_all = TRUE) |>
    transmute(opp_id, text = str_squish(paste(eligibility_text, summary)))
  items <- ask |> inner_join(ex, by = "opp_id") |> filter(nzchar(text))
  calls <- new.env(); calls$n <- 0L
  res <- purrr::map_dfr(seq_len(nrow(items)), function(i)
    dplyr::bind_cols(tibble::tibble(opp_id = items$opp_id[i]), read_notice(items$text[i], live, calls, chat_fn)))
  message(sprintf("%d ask items with text; %d labeled (cache %d, live %d); %d skipped (no cache, live off or cap %d reached)",
    nrow(items), sum(!res$skipped), sum(res$cached & !res$skipped), calls$n, sum(res$skipped), NOTICE_MAX_CALLS))
  res
}

if (sys.nframe() == 0) {
  out <- run_notice_reader()
  write_csv(out |> select(-skipped), here::here("data", "processed", "notice_reader.csv"))
}

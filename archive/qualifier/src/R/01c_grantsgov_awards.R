# 01c_grantsgov_awards.R — award amounts and deadlines as Grants.gov publishes them.
# For every state-eligible opportunity, reads the full Grants.gov record (fetchOpportunity,
# cached in data/cache/api/grantsgov/fetch/) and keeps the current record's award ceiling,
# award floor, estimated total funding, expected number of awards, and application deadline.
# "Current record" means the synopsis for posted opportunities and the forecast for forecasts
# (Grants.gov's docType field).
#
# Run standalone (first run makes ~600 API calls, about 10 minutes; later runs are offline):
#   Rscript src/R/01c_grantsgov_awards.R
# Output: data/processed/grantsgov_awards.rds

gg_num <- function(x) {
  v <- suppressWarnings(as.numeric(x %||% NA))
  if (length(v) == 0 || is.na(v) || v <= 1) NA_real_ else v   # Grants.gov uses 0 or 1 for "not stated"
}

gg_date <- function(x) {
  if (is.null(x) || !nzchar(x)) return(as.Date(NA))
  as.Date(substr(x, 1, 12), format = "%b %d, %Y")
}

parse_award_details <- function(path) {
  d <- fromJSON(path, simplifyVector = FALSE)$data
  doc <- d$docType %||% (if (!is.null(d$synopsis)) "synopsis" else "forecast")
  rec <- if (identical(doc, "forecast")) d$forecast else d$synopsis
  if (is.null(rec)) rec <- d$synopsis %||% d$forecast %||% list()
  deadline <- if (identical(doc, "forecast")) gg_date(rec$estApplicationResponseDate) else gg_date(rec$responseDate)
  tibble(
    gg_record = doc,
    # A ceiling under $1,000 is a placeholder (one forecast lists $6 beside $1.5M in funding).
    gg_award_ceiling = { v <- gg_num(rec$awardCeiling); if (!is.na(v) && v < 1000) NA_real_ else v },
    gg_award_floor = gg_num(rec$awardFloor),
    gg_est_funding = gg_num(rec$estimatedFunding),
    gg_n_awards = suppressWarnings(as.numeric(rec$numberOfAwards %||% NA)),
    gg_deadline = deadline,
    gg_deadline_note = (if (identical(doc, "forecast")) rec$estApplicationResponseDateDesc else rec$responseDateDesc) %||% NA_character_,
    gg_checked = read_accessed(path))
}

run_award_details <- function(g, status) {
  todo <- g |> filter(state_eligible) |> select(opportunity_number) |>
    left_join(select(status, opportunity_number, legacy_id), by = "opportunity_number") |>
    filter(!is.na(legacy_id))
  message("Reading Grants.gov records for ", nrow(todo), " state-eligible opportunities (cached after first run)")
  map2_dfr(todo$opportunity_number, todo$legacy_id, function(num, id) {
    out <- tryCatch(parse_award_details(gg_fetch_cached(id)),
                    error = function(e) { message("fetch failed: ", num, " ", conditionMessage(e)); NULL })
    if (is.null(out)) return(NULL)
    mutate(out, opportunity_number = num, .before = 1)
  })
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/01c_grantsgov_awards.R")
  for (f in c("00_config", "01_load_clean", "01a_grantsgov_enrich")) source(here::here("src", "R", paste0(f, ".R")))
  enrich <- readRDS(file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))
  awards <- run_award_details(grants, enrich$status)
  saveRDS(awards, file.path(DIR_PROCESSED, "grantsgov_awards.rds"))
  message("Records: ", nrow(awards), "; with an award ceiling: ", sum(!is.na(awards$gg_award_ceiling)),
          "; with a deadline: ", sum(!is.na(awards$gg_deadline)))
}

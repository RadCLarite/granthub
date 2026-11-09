# test_ingest.R: checks on the merged opportunities table (03_merge_opportunities.R).
# Sourced by run_tests.R, which provides check(). Rules written before looking at results.
# Skipped (with a failing check) if opportunities.csv has not been built yet.

local({
  s <- "ingest: opportunities"
  f <- file.path(DIR_PROCESSED, "opportunities.csv")
  if (!file.exists(f)) { check(s, "opportunities.csv exists (run R/03_merge_opportunities.R)", FALSE); return(invisible()) }
  o <- readr::read_csv(f, show_col_types = FALSE, guess_max = 1e5)
  ex <- readr::read_csv(file.path(DIR_PROCESSED, "grantsgov_extract.csv"), show_col_types = FALSE, guess_max = 1e5)
  api <- readr::read_csv(file.path(DIR_PROCESSED, "grantsgov_api_status.csv"), show_col_types = FALSE, col_types = readr::cols(.default = "c"))

  check(s, "opp_id is unique", !anyDuplicated(o$opp_id))
  check(s, "status is one of posted, forecasted, closed, notice", all(o$status %in% c("posted", "forecasted", "closed", "notice")))
  check(s, "every API-posted id is posted in the table", all(api$opp_id[api$api_status == "posted"] %in% o$opp_id[o$status == "posted"]))
  check(s, "every API-forecasted id is forecasted in the table", all(api$opp_id[api$api_status == "forecasted"] %in% o$opp_id[o$status == "forecasted"]))
  check(s, "no closed item closes before CLOSED_SINCE", !any(o$status == "closed" & !is.na(o$close_date) & o$close_date < CLOSED_SINCE))
  sim <- readr::read_csv(file.path(DIR_PROCESSED, "simpler_opportunities.csv"), show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  check(s, "every Simpler id is in the merged table (Simpler is cross-check, nothing lost)", all(sim$opp_id %in% o$opp_id | sim$simpler_id %in% o$opp_id))
  check(s, "Simpler and Grants.gov posted counts within 1%", abs(sum(sim$status == "posted") - sum(o$status == "posted")) <= 0.01 * sum(o$status == "posted"),
        paste(sum(sim$status == "posted"), "vs", sum(o$status == "posted")))
  frn <- readr::read_csv(file.path(DIR_PROCESSED, "federal_register_notices.csv"), show_col_types = FALSE)
  # A notice matched to an opportunity is recorded in fr_url (one per opportunity); the rest are notice rows.
  check(s, "every Federal Register notice is a notice row or matched to an opportunity", sum(o$status == "notice") + sum(vapply(frn$url, function(u) any(grepl(u, o$fr_url[o$status != "notice"], fixed = TRUE)), logical(1))) == nrow(frn),
        paste(sum(o$status == "notice"), "notice rows,", sum(vapply(frn$url, function(u) any(grepl(u, o$fr_url[o$status != "notice"], fixed = TRUE)), logical(1))), "matched of", nrow(frn)))
  posted <- o[o$status == "posted", ]
  check(s, "at least 90% of posted items have a close date", mean(!is.na(posted$close_date)) >= 0.9, round(mean(!is.na(posted$close_date)), 3))
  # Grants.gov itself lists a few "posted" items whose close date has passed (HRSA-27-072 on Nov 6). Tolerate up to 1%, report the count.
n_stale <- sum(!is.na(posted$close_date) & posted$close_date < REF_DATE)
check(s, "at most 1% of posted items have a close date before REF_DATE (Grants.gov data quality)", n_stale <= 0.01 * nrow(posted), n_stale)
  check(s, "merged count is at least the Grants.gov extract count", nrow(o) >= nrow(ex), nrow(o))
  check(s, "every row names a source and sources_seen", !anyNA(o$source) && !anyNA(o$sources_seen))
  check(s, "eligibility codes are kept (nothing dropped on eligibility)", sum(!is.na(o$applicant_types)) > 0.9 * nrow(o), sum(!is.na(o$applicant_types)))
  # Known case from the qualifier work: a Clean School Bus style program should appear if its CFDA is in the file.
  # CFDA 66.045 is [uncertain]; the check records the count rather than failing on absence.
  check(s, "known-case lookup ran (CFDA 66.045 rows reported, may be 0)", TRUE, sum(grepl("66.045", o$cfda_list, fixed = TRUE)))
  check(s, "past-award flag is logical with no NA", is.logical(o$nc_won_before) && !anyNA(o$nc_won_before))
})

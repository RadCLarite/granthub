# 02a_grantsgov_extract.R: Grants.gov daily XML extract -> data/processed/grantsgov_extract.csv
# Source: https://www.grants.gov/xml-extract (public, no key, about 75 MB zip / 300 MB XML).
# The extract holds every synopsis and forecast since 2014 (about 83,700 records). We keep
# the scope Kent chose: all open/forecasted, plus closed with a close date on or after
# CLOSED_SINCE. Eligibility is kept as a field; nothing is filtered on it here.
# Run from Finalists/src: Rscript R/02a_grantsgov_extract.R
# The zip is cached, so a rerun never re-downloads. Set EXTRACT_DATE to pin a day.

here::i_am("src/R/02a_grantsgov_extract.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(stringi); library(dplyr); library(purrr); library(readr); library(stringr); library(httr2) })

EXTRACT_DATE <- format(REF_DATE, "%Y%m%d")
zip_name <- paste0("GrantsDBExtract", EXTRACT_DATE, "v2")
zip_path <- file.path(DIR_CACHE_EXTRACT, paste0(zip_name, ".zip"))
xml_path <- file.path(DIR_CACHE_EXTRACT, paste0(zip_name, ".xml"))
dir.create(DIR_CACHE_EXTRACT, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(xml_path)) {
  if (!file.exists(zip_path)) {
    url <- paste0("https://prod-grants-gov-chatbot.s3.amazonaws.com/extracts/", zip_name, ".zip")
    message("Downloading ", url)
    httr2::request(url) |> httr2::req_user_agent("SolveAThon2026-student-team") |>
      httr2::req_retry(max_tries = 3) |> httr2::req_timeout(600) |>
      httr2::req_perform(path = zip_path)
    writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), paste0(zip_path, ".accessed"))
  }
  utils::unzip(zip_path, exdir = DIR_CACHE_EXTRACT)
}

# The file is pretty-printed XML with one flat record per Opportunity*Detail_1_0 element.
# Parsing it with xml2 node by node took over 10 minutes, so we cut the text into records
# and pull tags with vectorized stringi regexes (about a minute). Values stay as in the file
# (HTML entities such as &amp;apos; are left for the merge step to clean).
# Repeated tags (EligibleApplicants, CFDANumbers) are joined with "|".
txt <- readr::read_file(xml_path)
SINGLE_TAGS <- c("OpportunityID", "OpportunityNumber", "Version", "OpportunityTitle", "AgencyCode", "AgencyName",
  "OpportunityCategory", "FundingInstrumentType", "CategoryOfFundingActivity", "PostDate", "CloseDate",
  "EstimatedSynopsisCloseDate", "ArchiveDate", "LastUpdatedDate", "CloseDateExplanation",
  "EstimatedSynopsisCloseDateExplanation", "AwardFloor", "AwardCeiling", "EstimatedTotalProgramFunding",
  "ExpectedNumberOfAwards", "CostSharingOrMatchingRequirement", "AdditionalInformationOnEligibility",
  "Description", "AdditionalInformationURL", "GrantorContactEmail")
REPEAT_TAGS <- c("EligibleApplicants", "CFDANumbers")
parse_records <- function(tag, kind) {
  recs <- stringi::stri_extract_all_regex(txt, paste0("(?s)<", tag, ">.*?</", tag, ">"))[[1]]
  message(kind, ": ", length(recs), " records")
  one <- function(t) stringi::stri_match_first_regex(recs, paste0("(?s)<", t, ">(.*?)</", t, ">"))[, 2]
  out <- setNames(lapply(SINGLE_TAGS, one), SINGLE_TAGS)
  for (t in REPEAT_TAGS) {
    out[[t]] <- vapply(stringi::stri_match_all_regex(recs, paste0("<", t, ">(.*?)</", t, ">")),
      function(m) if (nrow(m) && !all(is.na(m[, 2]))) paste(unique(m[, 2][nzchar(m[, 2])]), collapse = "|") else NA_character_,
      character(1))
  }
  tibble::as_tibble(out) |> mutate(record_type = kind)
}
raw <- bind_rows(
  parse_records("OpportunitySynopsisDetail_1_0", "synopsis"),
  parse_records("OpportunityForecastDetail_1_0", "forecast")
)
rm(txt); invisible(gc())

d8 <- function(x) as.Date(x, format = "%m%d%Y")
num <- function(x) suppressWarnings(as.numeric(x))
col <- function(df, nm) if (nm %in% names(df)) df[[nm]] else rep(NA_character_, nrow(df))

ex <- raw |> transmute(
  opp_id = col(raw, "OpportunityID"), opp_number = col(raw, "OpportunityNumber"),
  record_type, version = col(raw, "Version"),
  title = col(raw, "OpportunityTitle"), agency_code = col(raw, "AgencyCode"), agency = col(raw, "AgencyName"),
  category = col(raw, "OpportunityCategory"), funding_instrument = col(raw, "FundingInstrumentType"),
  funding_activity = col(raw, "CategoryOfFundingActivity"),
  post_date = d8(col(raw, "PostDate")),
  close_date = if_else(record_type == "forecast", d8(col(raw, "EstimatedSynopsisCloseDate")), d8(col(raw, "CloseDate"))),
  archive_date = d8(col(raw, "ArchiveDate")), last_updated = d8(col(raw, "LastUpdatedDate")),
  close_date_note = coalesce(col(raw, "CloseDateExplanation"), col(raw, "EstimatedSynopsisCloseDateExplanation")),
  award_floor = num(col(raw, "AwardFloor")), award_ceiling = num(col(raw, "AwardCeiling")),
  est_total_funding = num(col(raw, "EstimatedTotalProgramFunding")), n_awards = num(col(raw, "ExpectedNumberOfAwards")),
  cost_sharing = col(raw, "CostSharingOrMatchingRequirement"),
  applicant_type_codes = col(raw, "EligibleApplicants"), eligibility_text = col(raw, "AdditionalInformationOnEligibility"),
  cfda_list = col(raw, "CFDANumbers"), summary = col(raw, "Description"),
  info_url = col(raw, "AdditionalInformationURL"),
  contact_email = col(raw, "GrantorContactEmail")
)

# Keep the latest version of each opportunity id.
ex <- ex |> arrange(opp_id, desc(last_updated)) |> distinct(opp_id, .keep_all = TRUE)

# Status is derived (the extract has no status field). Rule, in order:
#  forecast record -> "forecasted" (until its archive date passes);
#  close date on/after REF_DATE, or no close date and not archived -> "posted";
#  otherwise "closed".
ex <- ex |> mutate(
  status = case_when(
    record_type == "forecast" & (is.na(archive_date) | archive_date >= REF_DATE) ~ "forecasted",
    record_type == "forecast" ~ "closed",
    !is.na(close_date) & close_date >= REF_DATE ~ "posted",
    is.na(close_date) & (is.na(archive_date) | archive_date >= REF_DATE) ~ "posted",
    TRUE ~ "closed"),
  is_forecast = status == "forecasted",
  is_recent_closed = status == "closed" & !is.na(close_date) & close_date >= CLOSED_SINCE,
  url = paste0("https://www.grants.gov/search-results-detail/", opp_id),
  source = "grantsgov_extract")

scoped <- ex |> filter(status %in% c("posted", "forecasted") | is_recent_closed)
message("All records: ", nrow(ex), " | in scope: ", nrow(scoped))
print(count(scoped, status, record_type))

dir.create(DIR_PROCESSED, showWarnings = FALSE, recursive = TRUE)
readr::write_csv(scoped, file.path(DIR_PROCESSED, "grantsgov_extract.csv"))
message("Wrote data/processed/grantsgov_extract.csv")

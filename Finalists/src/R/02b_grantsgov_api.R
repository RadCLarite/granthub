# 02b_grantsgov_api.R: live Grants.gov status check against the XML extract.
# The extract has no status field, so 02a derives one. search2 returns the official status for
# every posted and forecasted opportunity (about 884 and 588 on Nov 6; rows = 5000 fits in one
# call each). This script caches both responses, writes the official id list, and logs ids the
# extract and the API disagree on. 03_merge_opportunities.R trusts the API for these two statuses.
# Run from Finalists/src: Rscript R/02b_grantsgov_api.R   (cached; delete the cache file to refresh)

here::i_am("src/R/02b_grantsgov_api.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr) })

DIR_STATUS <- file.path(DIR_CACHE_API, "grantsgov_status")
pull_status <- function(st) {
  # Cache key includes REF_DATE so a new day is a new snapshot; old ones stay for the record.
  body <- list(keyword = "", rows = 5000L, startRecordNum = 0L, oppStatuses = st, snapshot = as.character(REF_DATE))
  x <- cached_fetch(paste0(GRANTSGOV_API_BASE, "/search2"), body = body, dir = DIR_STATUS, parse = "json")
  h <- x$data$oppHits
  if (x$data$hitCount > nrow(h)) warning(st, ": hitCount ", x$data$hitCount, " > rows returned ", nrow(h))
  tibble::as_tibble(h) |> transmute(opp_id = as.character(id), opp_number = number, title, agency_code = agencyCode,
    api_status = st, open_date = openDate, close_date_api = closeDate, cfda_list_api = map_chr(cfdaList, ~ paste(.x, collapse = "|")))
}
api <- bind_rows(pull_status("posted"), pull_status("forecasted"))
message("API: ", paste(names(table(api$api_status)), table(api$api_status), collapse = ", "))
write_csv(api, file.path(DIR_PROCESSED, "grantsgov_api_status.csv"))

ex <- read_csv(file.path(DIR_PROCESSED, "grantsgov_extract.csv"), show_col_types = FALSE, col_types = cols(.default = "c")) |>
  select(opp_id, status)
cmp <- full_join(api |> select(opp_id, api_status), ex, by = "opp_id") |>
  mutate(agree = !is.na(api_status) & !is.na(status) & api_status == status)
message("Agree: ", sum(cmp$agree))
message("In API, not in extract scope: ", sum(is.na(cmp$status)), " (extract is a day old or id missing)")
message("Extract says open, API does not: ", sum(is.na(cmp$api_status) & cmp$status %in% c("posted", "forecasted")))
print(count(cmp |> filter(!agree), api_status, status))
write_csv(cmp |> filter(!agree), file.path(DIR_PROCESSED, "grantsgov_status_disagreements.csv"))

# 02g_research_unmatched.R: Grants.gov post date, cost sharing and link for pool rows that opportunities.csv lacks.
# Read-only: one POST to Grants.gov fetchOpportunity per id, cached in data/cache/api/grantsgov_detail (a rerun makes no calls).
# Ids = rows of research_opportunities.csv not in opportunities.csv. Writes data/processed/research_grantsgov_lookup.csv,
# which 14_build_research_payload.R merges for those rows. An id Grants.gov does not know is skipped and reported.
# Run from the repo root: Rscript R/02g_research_unmatched.R

here::i_am("R/02g_research_unmatched.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_io.R"))
source(here::here("R", "helpers_research.R"))

pool <- readr::read_csv(file.path(DIR_PROCESSED, "research_opportunities.csv"), col_types = readr::cols(.default = "c"), show_col_types = FALSE)
gg <- readr::read_csv(file.path(DIR_PROCESSED, "opportunities.csv"), col_types = readr::cols(.default = "c"), show_col_types = FALSE)
ids <- unmatched_opp_ids(pool, gg)
message(length(ids), " pool rows are not in opportunities.csv")

rows <- lapply(ids, function(id) {
  x <- tryCatch(
    cached_fetch(paste0(GRANTSGOV_API_BASE, "/fetchOpportunity"), body = list(opportunityId = as.integer(id)),
                 dir = file.path(DIR_CACHE_API, "grantsgov_detail"), parse = "json"),
    error = function(e) NULL)
  d <- parse_grantsgov_detail(x)
  if (is.null(x) || (is.na(d$post_date) && is.na(d$cost_sharing))) { message("  skipped ", id, ": no usable record"); return(NULL) }
  tibble::tibble(opp_id = id, url = grantsgov_url(id), post_date = d$post_date, cost_sharing = d$cost_sharing)
})
lookup <- dplyr::bind_rows(rows)
readr::write_csv(lookup, file.path(DIR_PROCESSED, "research_grantsgov_lookup.csv"))
message("Wrote ", nrow(lookup), " of ", length(ids), " rows to research_grantsgov_lookup.csv")

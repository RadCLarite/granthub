# 02e_simpler_grants.R: Simpler.Grants.gov search API -> data/processed/simpler_opportunities.csv
# Cross-check and gap filler for the Grants.gov extract (Simpler is the new official front end,
# so most rows overlap; the value is a second source for status, eligibility and award fields).
# Needs SIMPLER_GRANTS_KEY in the environment (.Renviron, never in a file). Cached per page, so a
# rerun without a key works as long as the cache exists.
# Run from Finalists/src: Rscript R/02e_simpler_grants.R

here::i_am("src/R/02e_simpler_grants.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(stringr) })

DIR_SIMPLER <- file.path(DIR_CACHE_API, "simpler")
key <- Sys.getenv("SIMPLER_GRANTS_KEY")
PAGE_SIZE <- 100L
get_page <- function(p) {
  body <- list(filters = list(opportunity_status = list(one_of = list("posted", "forecasted"))),
               pagination = list(page_offset = p, page_size = PAGE_SIZE,
                                 sort_order = list(list(order_by = "opportunity_id", sort_direction = "ascending"))))
  # The cache key carries the date, so a new day is a new snapshot and old ones stay on disk.
  cached_fetch(paste0(SIMPLER_BASE, "/v1/opportunities/search"), body = body, dir = DIR_SIMPLER, parse = "json", key = paste0("simpler_", REF_DATE, "_p", p),
               headers = if (nzchar(key)) list(`X-API-Key` = key) else NULL)
}
x1 <- get_page(1L); n_pages <- x1$pagination_info$total_pages
message("Simpler: ", x1$pagination_info$total_records, " records, ", n_pages, " pages")
pages <- c(list(x1), lapply(seq_len(n_pages)[-1], get_page))

flat <- function(d) {
  s <- d$summary
  tibble(simpler_id = d$opportunity_id, opp_id = as.character(d$legacy_opportunity_id), opp_number = d$opportunity_number,
         title = d$opportunity_title, agency = d$agency_name, agency_code = d$agency_code, status = d$opportunity_status,
         category = d$category, post_date = as.Date(s$post_date), close_date = as.Date(s$close_date),
         archive_date = as.Date(s$archive_date), award_floor = s$award_floor, award_ceiling = s$award_ceiling,
         est_total_funding = s$estimated_total_program_funding, n_awards = s$expected_number_of_awards,
         is_cost_sharing = s$is_cost_sharing, applicant_types = map_chr(s$applicant_types, ~ paste(.x, collapse = "|")),
         eligibility_text = s$applicant_eligibility_description,
         funding_instruments = map_chr(s$funding_instruments, ~ paste(.x, collapse = "|")),
         cfda_list = map_chr(d$opportunity_assistance_listings, ~ if (is.data.frame(.x) && nrow(.x)) paste(.x$assistance_listing_number, collapse = "|") else NA_character_),
         summary = str_squish(str_remove_all(s$summary_description, "<[^>]+>")),
         url = paste0("https://simpler.grants.gov/opportunity/", d$opportunity_id), source = "simpler")
}
out <- map_dfr(pages, ~ flat(.x$data)) |> distinct(simpler_id, .keep_all = TRUE)
write_csv(out, file.path(DIR_PROCESSED, "simpler_opportunities.csv"))
message("Wrote simpler_opportunities.csv: ", nrow(out), " rows; status: ", paste(names(table(out$status)), table(out$status), collapse = ", "))

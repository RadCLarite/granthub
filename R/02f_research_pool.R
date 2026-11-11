# 02f_research_pool.R: Simpler.Grants.gov search API -> data/processed/research_opportunities.csv
# Optional refresh for the researcher tab pool. Same paging as 02e_simpler_grants.R, but with no agency or
# eligibility filter and its own cache directory (data/cache/api/simpler_research/), keyed by AS_OF_DATE
# (not REF_DATE), so the NC cache, simpler_opportunities.csv and the frozen snapshot are untouched.
# Running it overwrites nothing else: it writes only research_opportunities.csv and its own cache files.
# Needs SIMPLER_GRANTS_KEY in the environment (never in a tracked file). Without a key it works only
# if every page is already cached; otherwise it stops with a message.
# NOT RUN in the phase 1 build: the owner adds the key later. After running it, run in order:
#   Rscript R/14_build_research_payload.R
#   node tests/research/run_testset.js    (compare the pool size and test-set summary with docs/research_testset_results.md)
# Run from the repo root: Rscript R/02f_research_pool.R

here::i_am("R/02f_research_pool.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_io.R"))
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(stringr) })

DIR_SIMPLER_RESEARCH <- file.path(DIR_CACHE_API, "simpler_research")
key <- Sys.getenv("SIMPLER_GRANTS_KEY")
PAGE_SIZE <- 100L
cache_key <- function(p) paste0("simpler_research_", AS_OF_DATE, "_p", p)
if (!nzchar(key) && !file.exists(file.path(DIR_SIMPLER_RESEARCH, paste0(cache_key(1L), ".json")))) {
  stop("SIMPLER_GRANTS_KEY is empty and there is no cached research pool for ", AS_OF_DATE,
       ". Set the key in the environment and rerun.", call. = FALSE)
}
get_page <- function(p) {
  body <- list(filters = list(opportunity_status = list(one_of = list("posted", "forecasted"))),
               pagination = list(page_offset = p, page_size = PAGE_SIZE,
                                 sort_order = list(list(order_by = "opportunity_id", sort_direction = "ascending"))))
  cached_fetch(paste0(SIMPLER_BASE, "/v1/opportunities/search"), body = body, dir = DIR_SIMPLER_RESEARCH, parse = "json",
               key = cache_key(p), headers = if (nzchar(key)) list(`X-API-Key` = key) else NULL)
}
x1 <- get_page(1L); n_pages <- x1$pagination_info$total_pages
message("Simpler research pool: ", x1$pagination_info$total_records, " records, ", n_pages, " pages")
pages <- c(list(x1), lapply(seq_len(n_pages)[-1], get_page))

# Simpler gives applicant types by name; helpers_research.R (RESEARCH_ELIGIBLE_CODES) reads Grants.gov codes.
TYPE_CODES <- c(state_governments = "00", county_governments = "01", city_or_township_governments = "02",
                special_district_governments = "04", independent_school_districts = "05",
                public_and_state_institutions_of_higher_education = "06",
                federally_recognized_native_american_tribal_governments = "07",
                public_and_indian_housing_authorities = "08", other_native_american_tribal_organizations = "11",
                nonprofits_non_higher_education_with_501c3 = "12", nonprofits_non_higher_education_without_501c3 = "13",
                private_institutions_of_higher_education = "20", individuals = "21",
                for_profit_organizations_other_than_small_businesses = "22", small_businesses = "23",
                other = "25", unrestricted = "99")
# An unknown name becomes the token UNMAPPED so the row stays visible; helpers_research.R strips that token from elig and keeps a row whose only type is UNMAPPED (eligibility unknown).
UNMAPPED_SEEN <- character()
type_codes <- function(x) {
  nm <- unlist(x); v <- unname(TYPE_CODES[nm])
  bad <- is.na(v); UNMAPPED_SEEN <<- union(UNMAPPED_SEEN, nm[bad])
  v[bad] <- "UNMAPPED"
  paste(v, collapse = "|")
}

flat <- function(d) {
  s <- d$summary
  tibble(opp_id = ifelse(is.na(d$legacy_opportunity_id), paste0("S", d$opportunity_id), as.character(d$legacy_opportunity_id)), opp_number = d$opportunity_number,
         title = d$opportunity_title, agency = d$agency_name, agency_code = d$agency_code, status = d$opportunity_status,
         close_date = as.Date(s$close_date), forecasted_close_date = as.Date(s$forecasted_close_date), award_floor = s$award_floor, award_ceiling = s$award_ceiling,
         applicant_types = map_chr(s$applicant_types, type_codes),
         summary = str_squish(str_remove_all(s$summary_description, "<[^>]+>")),
         url = paste0("https://simpler.grants.gov/opportunity/", d$opportunity_id),
         fetched_on = as.character(AS_OF_DATE))
}
out <- map_dfr(pages, ~ flat(.x$data)) |> distinct(opp_id, .keep_all = TRUE)
if (length(UNMAPPED_SEEN)) message("Unmapped applicant-type names (add to TYPE_CODES): ", paste(UNMAPPED_SEEN, collapse = ", "))
only_unmapped <- out$applicant_types == "UNMAPPED"
message("Rows whose only applicant type is UNMAPPED (kept in the pool with eligibility unknown): ", sum(only_unmapped))
write_csv(out, file.path(DIR_PROCESSED, "research_opportunities.csv"))
message("Wrote research_opportunities.csv: ", nrow(out), " rows; status: ", paste(names(table(out$status)), table(out$status), collapse = ", "))

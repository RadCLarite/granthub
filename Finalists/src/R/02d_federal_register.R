# 02d_federal_register.R: Federal Register notices about funding opportunities -> data/processed/federal_register_notices.csv
# Source: federalregister.gov API v1 (public, no key). Searches the last 12 months for
# "notice of funding opportunity" / "notice of funding availability" / "notice inviting applications".
# These are announcements, not the opportunity record itself: 03 matches them to Grants.gov rows by
# opportunity number found in the title or abstract; unmatched notices are kept as their own rows
# with status "notice" (published, open/closed state not verified). [uncertain: keyword recall]
# Run from Finalists/src: Rscript R/02d_federal_register.R   (cached)

here::i_am("src/R/02d_federal_register.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr); library(stringr) })

DIR_FR <- file.path(DIR_CACHE_API, "federalregister")
TERMS <- c('"notice of funding opportunity"', '"notice of funding availability"', '"notice inviting applications"')
FIELDS <- c("title", "abstract", "document_number", "html_url", "publication_date", "agencies", "type")
since <- format(REF_DATE - 365, "%Y-%m-%d")
fields_qs <- paste0("fields[]=", FIELDS, collapse = "&")

pull_term <- function(term) {
  pages <- list()
  for (p in 1:20) {
    q <- list(`conditions[term]` = term, `conditions[type][]` = "NOTICE", `conditions[publication_date][gte]` = since,
              `conditions[publication_date][lte]` = format(REF_DATE, "%Y-%m-%d"), per_page = 100, page = p, order = "oldest")
    x <- cached_fetch(paste0(FR_API_BASE, "/documents.json?", fields_qs), query = q, dir = DIR_FR, parse = "json")
    if (!NROW(x$results)) break
    pages[[p]] <- x$results |> as_tibble() |>
      mutate(agency = map_chr(agencies, ~ if (is.data.frame(.x) && nrow(.x)) paste(coalesce(.x$name, .x$raw_name), collapse = "; ") else NA_character_)) |>
      select(document_number, title, abstract, agency, publication_date, url = html_url)
    if (p >= (x$total_pages %||% 1)) break
  }
  bind_rows(pages) |> mutate(search_term = term)
}
fr <- map_dfr(TERMS, pull_term)
message("Federal Register rows before dedupe: ", nrow(fr))
fr <- fr |> group_by(document_number) |> summarise(across(c(title, abstract, agency, publication_date, url), first),
                                                    search_terms = paste(unique(search_term), collapse = "|"), .groups = "drop") |>
  mutate(publication_date = as.Date(publication_date), source = "federal_register")
write_csv(fr, file.path(DIR_PROCESSED, "federal_register_notices.csv"))
message("Wrote federal_register_notices.csv: ", nrow(fr), " notices")

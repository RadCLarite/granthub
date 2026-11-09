# 14_build_research_payload.R: opportunities.csv -> data/processed/research.json (researcher tab pool).
# Reads research_opportunities.csv if present, else opportunities.csv. Clock is AS_OF_DATE (00_config.R).
# Note: funding_activity in opportunities.csv is the Grants.gov category (HL = Health, ED = Education), not an NIH
# institute, so the IC code is taken from the opportunity number only.
# Run from the repo root: Rscript R/14_build_research_payload.R

here::i_am("R/14_build_research_payload.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_research.R"))

src <- here::here("data", "processed", "research_opportunities.csv")
if (!file.exists(src)) src <- here::here("data", "processed", "opportunities.csv")
opps <- readr::read_csv(src, col_types = readr::cols(.default = "c"), show_col_types = FALSE)

message("Input: ", basename(src))
payload <- build_research_payload(opps, AS_OF_DATE, REF_DATE)
message("source_date: ", payload$source_date, if ("fetched_on" %in% names(opps)) " (fetched_on column)" else " (REF_DATE; no fetched_on column)")
out <- here::here("data", "processed", "research.json")
jsonlite::write_json(payload, out, auto_unbox = TRUE, na = "null")
bytes <- file.size(out)
if (bytes > 2000000) stop("research.json is ", bytes, " bytes, over the 2,000,000 limit", call. = FALSE)
cat(sprintf("research.json: %d rows, %d bytes (built %s, listings fetched %s)\n", payload$n, bytes, payload$as_of, payload$source_date))

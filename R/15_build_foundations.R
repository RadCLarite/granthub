# 15_build_foundations.R: data/manual/foundations.csv -> data/processed/research_foundations.json (researcher tab).
# Stops, naming each problem, when a row lacks a source url or verified_on date. Clock is AS_OF_DATE (00_config.R).
# Env overrides for tests: FOUNDATIONS_CSV, FOUNDATIONS_OUT. Run from the repo root: Rscript R/15_build_foundations.R

here::i_am("R/15_build_foundations.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_research.R"))

env_or <- function(k, d) { v <- Sys.getenv(k, ""); if (nzchar(v)) v else d }
src <- env_or("FOUNDATIONS_CSV", here::here("data", "manual", "foundations.csv"))
out <- env_or("FOUNDATIONS_OUT", here::here("data", "processed", "research_foundations.json"))
df <- readr::read_csv(src, col_types = readr::cols(.default = "c"), show_col_types = FALSE)
errs <- validate_foundations(df, AS_OF_DATE)
if (length(errs)) stop("foundations.csv problems:\n  ", paste(errs, collapse = "\n  "), call. = FALSE)
payload <- build_foundations_payload(df, AS_OF_DATE)
jsonlite::write_json(payload, out, auto_unbox = TRUE, na = "null")
cat(sprintf("research_foundations.json: %d rows (built %s)\n", payload$n, payload$as_of))

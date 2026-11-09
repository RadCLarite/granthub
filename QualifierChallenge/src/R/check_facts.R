# check_facts.R — Phase 0 checkpoint: computed values vs build spec section 3.
# Run from anywhere: Rscript src/R/check_facts.R
here::i_am("src/R/check_facts.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "01_load_clean.R"))

facts <- compute_facts(grants)
dir.create(DIR_OUTS_TABLES, showWarnings = FALSE, recursive = TRUE)
readr::write_csv(facts, file.path(DIR_OUTS_TABLES, "verified_facts_check.csv"))
print(facts, n = Inf, width = 200)
cat("\n", sum(facts$result == "PASS"), "of", nrow(facts), "rows pass\n")

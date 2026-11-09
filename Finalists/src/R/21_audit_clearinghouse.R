# 21_audit_clearinghouse.R: Step 4 check (2:30) — Audit Clearinghouse as second awards source.
# Run from Finalists/src: Rscript R/21_audit_clearinghouse.R
# Source check: https://fac.gov/ and https://fac.gov/data/download/current-dictionary/
# Verdict (Kent decision): not available as a second awards-by-agency source. Do not bulk-download.
# FAC holds audit packages (audit PDF + Form SF-SAC), not NC awards by state agency.
# Its federal_awards CSV is keyed by report_id and ALN with amount_expended, with no DPI/DEQ/DHHS field.
# Joining it to USAspending receipts would not give a clean second source without a new bulk download and parsing.

here::i_am("src/R/21_audit_clearinghouse.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr) })

# TODO move to 00_config.R
CHECK_DATE <- "2026-11-07"

message("Audit Clearinghouse (FAC) check — ", CHECK_DATE)
message("FAC provides Single Audit packages (SF-SAC), not awards by state agency.")
message("federal_awards CSV fields are report_id, ALN, amount_expended; no agency_id for DPI/DEQ/DHHS.")
message("Result: not available as a second awards source. Keep USAspending (nc_awards_by_cfda.csv).")
message("Handoff to Kent: Audit Clearinghouse answer is not available, per Step 4 drop C and say not available.")

dir.create(here::here("outs", "figures"), showWarnings = FALSE, recursive = TRUE)
notes <- tibble(
  check = "audit_clearinghouse_by_state_agency",
  result = "not available",
  source = "https://fac.gov/data/download/current-dictionary/",
  date = CHECK_DATE,
  note = "FAC is audit packages, not awards by agency. No DPI/DEQ/DHHS field; would need bulk download and parse. Kent decision: do not pull."
)
write_csv(notes, file.path(DIR_OUTS, "audit_clearinghouse_check.csv"), na = "")
message("Wrote outs/audit_clearinghouse_check.csv (state-agency answer: not available)")
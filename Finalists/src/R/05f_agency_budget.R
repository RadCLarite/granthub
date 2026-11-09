# 05f_agency_budget.R: each agency's state General Fund base budget for FY 2025-26, from OSBM's public
# "Budget and Revenue Summary 2025-27" (Table 3, column "2025-26 Base Budget": current law before any recommended change).
# Source: https://osbm.nc.gov/media/4279/download  (cached at data/cache/osbm/budget_revenue_summary_2025_27.pdf; downloaded
# once if missing). Run from Finalists/src: Rscript R/05f_agency_budget.R. Writes data/processed/agency_budget.csv.
# Only the base column is used, never the Governor's recommended changes. DOT and the Highway Patrol run on the Highway Fund and
# the Fire Marshal has no line in this table, so they get NA, not zero.

here::i_am("src/R/05f_agency_budget.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr) })

src_url <- "https://osbm.nc.gov/media/4279/download"
pdf <- here::here("data", "cache", "osbm", "budget_revenue_summary_2025_27.pdf")
if (!file.exists(pdf)) { dir.create(dirname(pdf), recursive = TRUE, showWarnings = FALSE); download.file(src_url, pdf, mode = "wb", quiet = TRUE) }

txt <- pdftools::pdf_text(pdf)
lines <- unlist(strsplit(txt[4:7], "\n"))
lines <- lines[grepl("^\\s*[0-9]{3}[0-9X]{2}\\s", lines)]
tab <- tibble(code = str_match(lines, "^\\s*([0-9X]{5})")[, 2],
              name = str_trim(str_match(lines, "^\\s*[0-9X]{5}\\s+(.+?)\\s{2,}")[, 2]),
              base = suppressWarnings(as.numeric(gsub(",", "", str_match(lines, "^\\s*[0-9X]{5}\\s+.+?\\s{2,}([0-9,]+|-)\\s")[, 2])))) |>
  distinct(code, .keep_all = TRUE)

codes <- list(dpi = "13510", ncccs = "16800", unc = "160XX", osbm = "13005", hfa = "13010", dmva = "13050", sos = "13200", osa = "13300",
  dst = c("13410", "13412"), doi = "13900", doa = "14100", oshr = "14111", osc = "14160", ncdit = "14660", dor = "14700", ncsbe = "18025",
  oah = "18210", dhhs = c("14410", "14411", "14420", "14430", "14435", "14440", "14445", "14450", "14460", "14470", "14480"),
  ids = "12001", doj = "13600", dps = "14550", dac = "15010", sbi = "15020", dacs = "13700", dol = "13800", deq = "14300", wrc = "14350",
  commerce = c("14600", "14601", "14602"), dncr = "14800", ncdot = character(0), shp = character(0), osfm = character(0))
out <- bind_rows(lapply(names(codes), function(a) {
  cc <- codes[[a]]; v <- tab$base[match(cc, tab$code)]
  tibble(agency_id = a, budget_codes = paste(cc, collapse = "|"), gf_base_fy2526 = if (length(cc) && all(!is.na(v))) sum(v) else NA_real_,
         note = if (!length(cc)) "Not in the General Fund table (Highway Fund or no separate line)" else NA_character_)
}))
miss <- out$agency_id[out$budget_codes != "" & is.na(out$gf_base_fy2526)]
if (length(miss)) stop("Budget codes not found in the PDF for: ", paste(miss, collapse = ", "))
out$source <- "OSBM Budget and Revenue Summary 2025-27, Table 3, 2025-26 Base Budget (General Fund)"
write_csv(out, file.path(DIR_PROCESSED, "agency_budget.csv"), na = "")
message("Wrote agency_budget.csv: ", sum(!is.na(out$gf_base_fy2526)), " of ", nrow(out), " agencies with a General Fund base budget")

# 05e_federal_obligations.R: federal spending per program (Assistance Listing), from SAM.gov's public
# Assistance Listings file already in data/raw (field "Obligations (122)": FY 24 actual, FY 25 actual or estimate, FY 26 estimate).
# Run from Finalists/src: Rscript R/05e_federal_obligations.R   Offline; reads only; writes data/processed/federal_obligations.csv.
# Amounts of several assistance types in one listing are added. A listing whose three years are all $0 is written as
# unknown (NA), not zero: SAM shows $0 for many formula programs that do spend money.

here::i_am("src/R/05e_federal_obligations.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(stringr); library(purrr) })

f <- here::here("data", "raw", "sam_assistance_listings", "AssistanceListings_DataGov_PUBLIC_CURRENT.csv")
al <- read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character()), locale = locale(encoding = "UTF-8"))
clean <- function(x) iconv(x, "UTF-8", "UTF-8", sub = "")
ob <- clean(al[["Obligations (122)"]])
fy_sum <- function(txt, fy) {
  m <- str_match_all(txt, paste0("FY\\s*", fy, "\\s*(?:est\\.?)?\\s*\\$\\s*([0-9,]+(?:\\.[0-9]+)?)"))[[1]]
  if (!nrow(m)) return(NA_real_)
  sum(as.numeric(gsub(",", "", m[, 2])))
}
out <- tibble(cfda = str_trim(clean(al[["Program Number"]])), program = str_trim(clean(al[["Program Title"]])),
              fy24 = map_dbl(ob, fy_sum, fy = 24), fy25 = map_dbl(ob, fy_sum, fy = 25), fy26 = map_dbl(ob, fy_sum, fy = 26)) |>
  mutate(allzero = coalesce(fy24, 0) == 0 & coalesce(fy25, 0) == 0 & coalesce(fy26, 0) == 0,
         across(c(fy24, fy25, fy26), \(x) ifelse(allzero, NA_real_, x))) |>
  select(-allzero) |> distinct(cfda, .keep_all = TRUE)
write_csv(out, file.path(DIR_PROCESSED, "federal_obligations.csv"), na = "")
message("Wrote federal_obligations.csv: ", nrow(out), " listings; ", sum(!is.na(out$fy25)), " with an FY 25 amount")

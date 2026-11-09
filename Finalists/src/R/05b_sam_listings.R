# 05b_sam_listings.R: builds data/processed/sam_listings.csv from the public SAM.gov
# Assistance Listings bulk file (the CFDA catalog). LOCAL FILE ONLY: this script never
# calls an outside service and needs no package beyond base R.
# Run from Finalists/src/:   Rscript R/05b_sam_listings.R
#
# Source: GSA, SAM.gov Assistance Listings, data.gov public extract (CC0)
#   https://s3.amazonaws.com/falextracts/Assistance%20Listings/datagov/AssistanceListings_DataGov_PUBLIC_CURRENT.csv
#   Downloaded 2026-11-07 (server last-modified 2026-11-01) to
#   data/raw/sam_assistance_listings/. The file is cp1252, not UTF-8.
#
# Output, one row per listing (CFDA number):
#   cfda, title, popular_name, federal_agency, authorization (statutory authority, field 040),
#   assistance_types, applicant_eligibility, matching (field 101), award_range (field 123),
#   sam_url, in_open_pool (the CFDA appears on a posted, forecasted or notice row of
#   data/processed/opportunities.csv)
# Long text fields are kept whole; display truncation is the tool's job.
# Use in the score or the app is Kent's call. Nothing here is model output.

here::i_am("src/R/05b_sam_listings.R")
source(here::here("src", "R", "00_config.R"))

SAM_FILE <- file.path(DIR_RAW, "sam_assistance_listings", "AssistanceListings_DataGov_PUBLIC_CURRENT.csv")
OUT_FILE <- file.path(DIR_PROCESSED, "sam_listings.csv")   # TODO move to 00_config.R
POOL_STATUSES <- c("posted", "forecasted", "notice")        # TODO move to 00_config.R (same as the eval pool)

if (!file.exists(SAM_FILE)) stop("SAM bulk file not found: ", SAM_FILE, " (see data/raw/README.md for the URL).")

raw <- read.csv(SAM_FILE, fileEncoding = "cp1252", check.names = FALSE,
                colClasses = "character", na.strings = character(0))

clean <- function(x) {
  x <- gsub("<[^>]+>", " ", x)            # a few fields carry HTML (mailto links)
  x <- gsub("[\r\n\t]+", " ", x)
  x <- trimws(gsub(" {2,}", " ", x))
  ifelse(nzchar(x), x, NA_character_)
}
col <- function(name) {
  if (!name %in% names(raw)) stop("Column missing from SAM file: ", name)
  clean(raw[[name]])
}

out <- data.frame(
  cfda                  = trimws(raw[["Program Number"]]),
  title                 = col("Program Title"),
  popular_name          = col("Popular Name (020)"),
  federal_agency        = col("Federal Agency (030)"),
  authorization         = col("Authorization (040)"),
  assistance_types      = col("Types of Assistance (060)"),
  applicant_eligibility = col("Applicant Eligibility (081)"),
  matching              = col("Formula and Matching Requirements (101)"),
  award_range           = col("Range and Average of Financial Assistance (123)"),
  sam_url               = col("URL"),
  stringsAsFactors = FALSE
)

dups <- sum(duplicated(out$cfda))
if (dups) warning(dups, " duplicate CFDA numbers in the SAM file; first kept.")
CFDA_RE <- "^\\d{2}\\.[0-9A-Z]{2,4}$"   # lettered numbers (11.63A, 93.00B, 93.1CF) are real programs
bad <- !grepl(CFDA_RE, out$cfda)
if (any(bad)) warning(sum(bad), " rows dropped, not a CFDA number: ", paste(head(out$cfda[bad]), collapse = ", "))
out <- out[!duplicated(out$cfda) & !bad, ]

# Which listings back at least one open opportunity in our pool
opps <- read.csv(OPPS_FILE, colClasses = "character")
pool <- opps[opps$status %in% POOL_STATUSES, ]
pool_cfda <- unique(trimws(unlist(strsplit(pool$cfda_list[!is.na(pool$cfda_list)], "[|;, ]+"))))
pool_cfda <- pool_cfda[grepl(CFDA_RE, pool_cfda)]
out$in_open_pool <- out$cfda %in% pool_cfda
out <- out[order(out$cfda), ]

write.csv(out, OUT_FILE, row.names = FALSE, na = "")

has_cfda <- !is.na(pool$cfda_list) & grepl("\\d{2}\\.\\d{3}", pool$cfda_list)
row_hit <- vapply(strsplit(ifelse(has_cfda, pool$cfda_list, ""), "[|;, ]+"),
                  function(v) any(trimws(v) %in% out$cfda), logical(1))
cat("Wrote", OUT_FILE, ":", nrow(out), "listings (", nrow(raw), "rows in the SAM file )\n")
cat("Listings with a statutory authority (field 040):", sum(!is.na(out$authorization)), "\n")
cat("Open pool rows:", nrow(pool), "| with a CFDA:", sum(has_cfda),
    "| CFDA found in SAM:", sum(row_hit), "\n")
cat("Distinct pool CFDAs:", length(pool_cfda), "| not in SAM file:",
    sum(!pool_cfda %in% out$cfda), "\n")

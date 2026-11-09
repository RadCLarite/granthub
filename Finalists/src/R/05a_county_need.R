# 05a_county_need.R: builds data/processed/county_need.csv from the qualifier's cached
# county data. CACHES ONLY: this script never calls an outside service and needs no
# package beyond base R. Run from Finalists/src/:   Rscript R/05a_county_need.R
#
# Output (long format): county, fips, indicator, label, value, percentile
#   percentile = share of the other NC counties with a lower value (0 to 1), the same
#   rule as dplyr::percent_rank, which the qualifier used in 05_export_tool_data.R.
#   High percentile = higher value = more need. Display or score use is Kent's call.
#
# Indicator definitions copy QualifierChallenge/src/R/05_export_tool_data.R
# (build_county_indicators and domain_indicators); change them there first.
#
# Sources and access dates: see data/cache/api/*.accessed (written by the qualifier pulls);
# CDC PLACES, HRSA and tigris have no .accessed record ("not found"). Printed at the end.

here::i_am("src/R/05a_county_need.R")
source(here::here("src", "R", "00_config.R"))   # OVERDOSE_YEARS and HPSA_AREA_TYPES live there

if (!dir.exists("../data/cache/api")) stop("Run this from Finalists/src/ (cache folder not found).")
OUT_FILE      <- "../data/processed/county_need.csv"

rd <- function(f) readRDS(file.path(DIR_CACHE_API, f))   # readRDS only; no fetch fallback by design
pad5 <- function(x) sprintf("%05d", as.integer(x))

# ---- CDC PLACES (crude prevalence, percent of adults) ----
pl <- as.data.frame(rd("places_nc_county.rds"))
ci <- data.frame(fips = pad5(pl$countyfips), county = pl$countyname, stringsAsFactors = FALSE)
for (m in c("mhlth", "depression", "binge", "access2", "foodinsecu", "foodstamp",
            "disability", "cognition", "lacktrpt", "housinsecu")) {
  ci[[m]] <- as.numeric(pl[[paste0(m, "_crudeprev")]])
}

# ---- HRSA shortage areas: distinct designated area/population designations per county ----
hpsa_count <- function(file) {
  d <- as.data.frame(rd(file))
  d <- d[d$common_state_abbreviation == "NC" & d$hpsa_status_code == "D" &
           d$hpsa_type_code %in% HPSA_AREA_TYPES, ]
  d$fips <- sprintf("%05s", d$state_and_county_federal_information_processing_standard_code)
  d$fips <- gsub(" ", "0", d$fips)
  d <- unique(d[, c("hpsa_id", "fips")])
  tab <- table(d$fips)
  setNames(as.numeric(tab), names(tab))
}
ci$pc_hpsa_count <- unname(hpsa_count("hrsa_pc.rds")[ci$fips])
ci$mh_hpsa_count <- unname(hpsa_count("hrsa_mh.rds")[ci$fips])

# ---- FEMA: distinct disaster declarations per county (cache holds declarations since 2016) ----
fe <- as.data.frame(rd("fema_declarations_nc.rds"))
fe$fips <- paste0(fe$fipsStateCode, fe$fipsCountyCode)
fe <- unique(fe[, c("disasterNumber", "fips")])
fe_tab <- table(fe$fips)
ci$fema_declarations <- unname(setNames(as.numeric(fe_tab), names(fe_tab))[ci$fips])

# Counties with no designation or declaration have zero (qualifier rule: coalesce to 0)
for (v in c("pc_hpsa_count", "mh_hpsa_count", "fema_declarations")) ci[[v]][is.na(ci[[v]])] <- 0

# ---- NCHS drug poisoning death rate per 100,000, mean over OVERDOSE_YEARS ----
od <- as.data.frame(rd("nchs_drug_poisoning_nc_county.rds"))
od <- od[as.integer(od$year) %in% OVERDOSE_YEARS, ]
od$fips <- pad5(od$fips)
od$rate <- as.numeric(od$model_based_death_rate)
od_m <- tapply(od$rate, od$fips, mean, na.rm = TRUE)
ci$overdose_rate <- unname(od_m[ci$fips])

# ---- ACS 2023 5-year (county) ----
ac <- as.data.frame(rd("acs_2023_nc_county.rds"))
pov_cols <- grep("^pov_u18_", names(ac), value = TRUE)   # same set the qualifier sums
ac$child_poverty_rate <- rowSums(ac[, pov_cols]) / ac$under18
ac$birth_rate    <- ac$births / ac$women_15_50
ac$age65_share   <- ac$age65 / ac$pop
ac$veteran_share <- ac$veterans / ac$civ_18plus
ac_use <- ac[, c("GEOID", "child_poverty_rate", "birth_rate", "age65_share", "veteran_share")]
ci <- merge(ci, ac_use, by.x = "fips", by.y = "GEOID", all.x = TRUE, sort = FALSE)

# ---- long format with percentiles ----
labels <- c(
  mhlth = "Adults with frequent mental distress (CDC PLACES, %)",
  depression = "Adults with depression (CDC PLACES, %)",
  mh_hpsa_count = "Mental health shortage areas (HRSA, count)",
  overdose_rate = paste0("Drug poisoning deaths per 100,000, ", min(OVERDOSE_YEARS), "-", max(OVERDOSE_YEARS), " average (NCHS model-based)"),
  binge = "Binge drinking (CDC PLACES, %)",
  birth_rate = "Births per woman aged 15-50 (ACS 2023)",
  access2 = "Adults 18-64 without insurance (CDC PLACES, %)",
  child_poverty_rate = "Children below poverty (ACS 2023, share)",
  housinsecu = "Housing insecurity (CDC PLACES, %)",
  foodinsecu = "Food insecurity (CDC PLACES, %)",
  foodstamp = "Received SNAP (CDC PLACES, %)",
  disability = "Any disability (CDC PLACES, %)",
  cognition = "Cognitive disability (CDC PLACES, %)",
  age65_share = "Share aged 65+ (ACS 2023)",
  veteran_share = "Veterans, share of civilian adults 18+ (ACS 2023)",
  lacktrpt = "Lack of reliable transportation (CDC PLACES, %)",
  pc_hpsa_count = "Primary care shortage designations (HRSA, count)",
  fema_declarations = "FEMA disaster declarations since 2016 (OpenFEMA, count)"
)
pct_rank <- function(x) (rank(x, ties.method = "min", na.last = "keep") - 1) / (sum(!is.na(x)) - 1)

long <- do.call(rbind, lapply(names(labels), function(v) {
  data.frame(county = ci$county, fips = ci$fips, indicator = v, label = labels[[v]],
             value = round(ci[[v]], 4), percentile = round(pct_rank(ci[[v]]), 4),
             stringsAsFactors = FALSE)
}))
long <- long[order(long$indicator, long$fips), ]
dir.create(dirname(OUT_FILE), showWarnings = FALSE, recursive = TRUE)
write.csv(long, OUT_FILE, row.names = FALSE, na = "")

cat("Wrote", OUT_FILE, ":", nrow(long), "rows,", length(unique(long$fips)), "counties,",
    length(labels), "indicators\n")
cat("Missing values per indicator (should be 0 for most):\n")
print(tapply(is.na(long$value), long$indicator, sum))
cat("\nAccess dates recorded by the qualifier pulls:\n")
for (f in list.files(DIR_CACHE_API, pattern = "\\.accessed$", full.names = TRUE)) {
  cat(" ", sub("\\.accessed$", "", basename(f)), ":", trimws(readLines(f, warn = FALSE)[1]), "\n")
}
cat("  not found (no .accessed file): places_nc_county.rds, hrsa_pc.rds, hrsa_mh.rds, nc_counties_tigris.rds\n")

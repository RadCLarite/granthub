# 02c_usaspending.R: past federal grant awards to NC government recipients, FY2022-FY2026.
# Source: USAspending API v2 /search/spending_by_award/ (public, no key). Backs the sponsors'
# "look at grants the agency has won before" point and gives a coverage baseline.
# Finding (Nov 6): recipient_type_names = "state_government" returns 0 rows for NC, while
# "government" returns about 12,800 awards that mix state agencies with cities and counties.
# So we pull "government" and flag state agencies by recipient name (STATE_AGENCY_REGEX in
# the script, a heuristic [uncertain]; review data/processed/nc_awards_recipients.csv).
# Output: data/processed/nc_awards_by_cfda.csv (cfda, recipient, n_awards, total_obligated, last_fy).
# Run from Finalists/src: Rscript R/02c_usaspending.R   (responses cached per page)

here::i_am("src/R/02c_usaspending.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(purrr); library(readr); library(stringr) })

DIR_USA <- file.path(DIR_CACHE_API, "usaspending")
PAGE_LIMIT <- 100L                       # API maximum per page
MAX_PAGES  <- 300L                       # safety stop; the NC pull is about 130 pages
STATE_AGENCY_REGEX <- "^NORTH CAROLINA |, NORTH CAROLINA|^STATE OF NORTH CAROLINA|NORTH CAROLINA DEPARTMENT|DEPARTMENT OF .*NORTH CAROLINA|^DEPARTMENT OF |^DIVISION OF |GOVERNORS OFFICE|^OFFICE OF |COMMISSION|NC DEPARTMENT"
LOCAL_REGEX <- "^CITY OF |, CITY OF$|^COUNTY OF |, COUNTY OF$|^TOWN OF |, TOWN OF$|AIRPORT|AUTHORITY|SCHOOL|TRIBE|NATION|BOARD OF EDUCATION|HOUSING"

fy_range <- function(fy) list(start_date = paste0(fy - 1, "-10-01"), end_date = paste0(fy, "-09-30"))
filters <- list(
  award_type_codes = c("02", "03", "04", "05"),             # grants (block, formula, project, cooperative agreement)
  time_period = list(list(start_date = fy_range(min(USA_FY))$start_date, end_date = fy_range(max(USA_FY))$end_date)),
  recipient_locations = list(list(country = "USA", state = "NC")),
  recipient_type_names = list("government"))
fields <- c("Award ID", "Recipient Name", "Award Amount", "Awarding Agency", "Assistance Listings", "Start Date")

url <- paste0(USASPENDING_BASE, "/search/spending_by_award/")
pages <- list()
for (p in seq_len(MAX_PAGES)) {
  body <- list(filters = filters, fields = fields, limit = PAGE_LIMIT, page = p, sort = "Award ID", order = "asc")
  x <- cached_fetch(url, body = body, dir = DIR_USA, parse = "json")
  r <- x$results
  if (is.null(r) || NROW(r) == 0) break
  pages[[p]] <- r
  if (!isTRUE(x$page_metadata$hasNext)) break
}
aw <- bind_rows(pages) |> as_tibble()
message("Awards pulled: ", nrow(aw), " (", length(pages), " pages)")

# Assistance Listings arrives as a list column of data frames: one award can carry several programs.
aw <- aw |>
  transmute(award_id = `Award ID`, recipient = `Recipient Name`, amount = `Award Amount`,
            awarding_agency = `Awarding Agency`, start_date = as.Date(`Start Date`),
            cfda = map(`Assistance Listings`, ~ if (is.data.frame(.x) && nrow(.x)) unique(.x$cfda_number) else NA_character_)) |>
  distinct(award_id, .keep_all = TRUE) |>
  unnest(cfda) |>
  mutate(fy = ifelse(as.integer(format(start_date, "%m")) >= 10,
                     as.integer(format(start_date, "%Y")) + 1L, as.integer(format(start_date, "%Y"))),
         recipient_class = case_when(
           str_detect(recipient, LOCAL_REGEX) ~ "local_or_other",
           str_detect(recipient, STATE_AGENCY_REGEX) ~ "state_agency",
           TRUE ~ "unclassified"))

dir.create(DIR_PROCESSED, showWarnings = FALSE, recursive = TRUE)
# For Kent to review the heuristic: every distinct recipient with its class and totals.
aw |> group_by(recipient, recipient_class) |>
  summarise(n_awards = n_distinct(award_id), total_obligated = sum(amount, na.rm = TRUE), .groups = "drop") |>
  arrange(desc(total_obligated)) |> write_csv(file.path(DIR_PROCESSED, "nc_awards_recipients.csv"))

# Award Amount is the award's total obligation to date, so it can repeat across a multi-program row; do not sum across CFDA.
by_cfda <- aw |> filter(recipient_class == "state_agency", !is.na(cfda)) |>
  group_by(cfda, recipient) |>
  summarise(n_awards = n_distinct(award_id), total_obligated = sum(amount, na.rm = TRUE), last_fy = max(fy, na.rm = TRUE), .groups = "drop") |>
  arrange(cfda, desc(total_obligated))
write_csv(by_cfda, file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv"))
message("Wrote nc_awards_by_cfda.csv: ", nrow(by_cfda), " rows, ", n_distinct(by_cfda$cfda), " CFDA programs")
print(count(aw |> distinct(recipient, recipient_class), recipient_class))

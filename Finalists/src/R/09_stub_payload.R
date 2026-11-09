# 09_stub_payload.R: Merge 1 STUB of payload.json and rankings_backtest.csv.
# Shapes follow saturday/03_contract.md so Marco (tool) and Everett (backtest) can build
# before the real ranking lands at Merge 2. Rows are real opportunities from
# opportunities.csv; every computed field (fit_score, eligibility, goal match, signature
# tier) is null because nothing is scored yet. Rank is close-date order, NOT a fit rank.
# Replaced by 10_run_ranking.R at Merge 2. Do not put any stub value on a slide.
# Run from Finalists/src: Rscript R/09_stub_payload.R

here::i_am("src/R/09_stub_payload.R")
source(here::here("src", "R", "00_config.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(jsonlite) })

STUB_DATA_AS_OF    <- "2026-11-07T09:30:00-05:00"
STUB_WINDOW_DAYS   <- 14L
ROLLING_CLOSE_DATE <- as.Date("2099-01-01")   # Grants.gov placeholder for no deadline
BACKTEST_SINCE     <- as.Date("2024-11-06")

opps <- read_csv(file.path(DIR_PROCESSED, "opportunities.csv"), show_col_types = FALSE,
                 col_types = cols(opp_id = "c", opp_number = "c", cfda_list = "c", .default = col_guess()))
amap <- read_csv(AGENCY_MAP_FILE, show_col_types = FALSE, col_types = cols(.default = "c"))
goals <- read_csv(here::here("src", "docs", "agency_goal_summaries.csv"), show_col_types = FALSE,
                  col_types = cols(.default = "c"))

# ---- agencies: 32 active, folded plans attached to their target -------------------------
active <- filter(amap, is.na(fold_into), is.na(drop_reason))
stopifnot(nrow(active) == 32)
stale <- goals |> group_by(plan_file) |> summarise(stale = any(plan_stale == "yes"), .groups = "drop")
agencies <- lapply(seq_len(nrow(active)), function(i) {
  a <- active[i, ]
  folded <- filter(amap, fold_into == a$agency_id)
  files <- c(a$plan_file, folded$plan_file)
  list(agency_id = a$agency_id, agency_name = a$agency_name, plan_files = I(files),
       plan_stale = any(stale$stale[stale$plan_file %in% files]),
       plan_thin = NA,                     # not measured yet
       folded_from = I(folded$agency_name))
})

# ---- rows: a few real items covering each status and the rolling-date case --------------
pick <- function(d, n = 1) head(arrange(d, opp_id), n)
dera <- filter(opps, opp_id == "363936")                      # DERA National, posted
fc   <- pick(filter(opps, status == "forecasted", close_date > REF_DATE, close_date < ROLLING_CLOSE_DATE))
nt   <- pick(filter(opps, status == "notice"))
roll <- pick(filter(opps, status == "posted", close_date == ROLLING_CLOSE_DATE))
stub_rows <- bind_rows(
  mutate(dera, agency_id = "deq"), mutate(dera, agency_id = "dpi"),
  mutate(bind_rows(roll, fc, nt), agency_id = "dhhs"))
stopifnot(nrow(stub_rows) == 5)

ref <- as.Date(substr(STUB_DATA_AS_OF, 1, 10))
to_row <- function(r) {
  rolling <- is.na(r$close_date) || r$close_date >= ROLLING_CLOSE_DATE
  close <- if (rolling) NULL else format(r$close_date)
  ceiling <- if (is.na(r$award_ceiling) || r$award_ceiling == 0) NULL else r$award_ceiling
  list(agency_id = r$agency_id, opp_id = r$opp_id, opp_number = r$opp_number, title = r$title,
       status = r$status, close_date = close,
       days_left = if (rolling) NULL else as.integer(r$close_date - ref),
       date_note = if (rolling) "rolling or no date listed" else NA,
       fit_score = NA, rank = r$rank, in_top10 = r$status == "posted",
       eligibility = "ask", elig_source = NA, elig_quote = NA,
       reader_label = NA, reader_quote = NA,
       goal_id = NA, goal_snippet = NA, opp_snippet = NA,
       cfda_list = r$cfda_list, award_ceiling = ceiling,
       signature_tier = "unknown", tier_source = NA,
       nc_won_before = isTRUE(as.logical(r$nc_won_before)), url = r$url)
}
stub_rows <- stub_rows |> group_by(agency_id) |>
  arrange(is.na(close_date), close_date, .by_group = TRUE) |> mutate(rank = row_number()) |> ungroup()
rows <- lapply(seq_len(nrow(stub_rows)), function(i) to_row(stub_rows[i, ]))

payload <- list(data_as_of = STUB_DATA_AS_OF, window_days = STUB_WINDOW_DAYS, stub = TRUE,
                agencies = agencies, rows = rows)
write_json(payload, PAYLOAD_JSON, auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE, digits = NA)

# ---- backtest stub: one 2-week DEQ window around the closed DERA Tribal item -------------
w_start <- as.Date("2024-11-25"); w_end <- w_start + 13
bt <- opps |>
  filter(status == "closed", close_date >= BACKTEST_SINCE, post_date <= w_end, close_date >= w_start) |>
  arrange(close_date, opp_id) |> head(5) |>
  transmute(agency_id = "deq", window_start = w_start, window_end = w_end, window_weeks = 2L,
            opp_id, opp_number, cfda_list, close_date, fit_score = NA_real_, rank = row_number())
write_csv(bt, BACKTEST_CSV, na = "")
message("STUB: wrote payload.json (", length(agencies), " agencies, ", length(rows),
        " rows) and rankings_backtest.csv (", nrow(bt), " rows)")

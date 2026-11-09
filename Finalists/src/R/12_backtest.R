# 12_backtest.R: rank closed opportunities with the same scoring as payload.json and write
# data/processed/rankings_backtest.csv (contract: saturday/03_contract.md).
# Windows: non-overlapping, WINDOW_WEEKS long (2, 4, 6), the first starting at CLOSED_SINCE and the
# last ending on or before REF_DATE [assumed grid; Everett may ask for another]. An item is in a
# window if it was posted on or before window_end and closes on or after window_start. Top BACKTEST_TOP_N
# per agency and window. Fit is scored on the closed set with its own keyword corpus: same function,
# so fit_score is comparable inside a window, not across files.
# Run: Rscript R/12_backtest.R

here::i_am("src/R/12_backtest.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "helpers_rank.R"))
source(here::here("src", "R", "score.R"))

stop_if_toy(CRITERIA_FILE)
cr <- read_criteria()
inp <- load_rank_inputs()
closed <- inp$opps |>
  filter(status == "closed", !is.na(close_date) | !is.na(date_note))
# prep_opportunities blanks rolling and far-future dates; the backtest needs a real close date.
raw_close <- as.Date(read_csv(OPPS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))$close_date)
names(raw_close) <- read_csv(OPPS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))$opp_id
closed$close_date <- raw_close[closed$opp_id]
closed <- closed |> filter(!is.na(close_date), close_date >= CLOSED_SINCE, close_date <= REF_DATE,
                           !is.na(post_date), close_date < FAR_FUTURE_DATE)
message(nrow(closed), " closed opportunities in range")

items <- build_items(closed, inp$ag, inp$plans, inp$pmap)
items$close_date <- as.Date(closed$close_date[match(items$opp_id, closed$opp_id)])
rk <- rank_by_agency(items, cr)$ranked
rk <- left_join(rk, items[, c("id", "opp_id", "opp_number", "post_date", "close_date")], by = "id") |>
  left_join(distinct(inp$opps[, c("opp_id", "cfda_list")]), by = "opp_id")

grid <- bind_rows(lapply(WINDOW_WEEKS, function(w) {
  start <- seq(CLOSED_SINCE, REF_DATE, by = 7 * w)
  tibble(window_weeks = w, window_start = start, window_end = start + 7 * w - 1)
})) |> filter(window_end <= REF_DATE)

out <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
  w <- grid[g, ]
  rk |> filter(post_date <= w$window_end, close_date >= w$window_start) |>
    group_by(agency_id) |> arrange(desc(total), opp_id, .by_group = TRUE) |> slice_head(n = BACKTEST_TOP_N) |>
    mutate(rank = row_number()) |> ungroup() |>
    transmute(agency_id, window_start = w$window_start, window_end = w$window_end, window_weeks = w$window_weeks,
              opp_id, opp_number, cfda_list, close_date, fit_score = round(total / 100, 4), rank)
}))
write_csv(out, BACKTEST_CSV, na = "")
message("Wrote rankings_backtest.csv: ", nrow(out), " rows, ", nrow(grid), " windows")

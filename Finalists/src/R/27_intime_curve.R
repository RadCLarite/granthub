# 27_intime_curve.R: the in-time curve (decision F): won programs reaching the Top 10, all vs in time
# (>= IN_TIME_DAYS days left at the window end), for each WINDOW_WEEKS window (2, 4, 6 weeks).
# Run from Finalists/src: Rscript R/27_intime_curve.R   Offline; reads only; writes data/processed/backtest_v2_intime_curve.csv.
# Same pool, ranking and "won" definition as 26_backtest_v2_intime.R (copied, looped over windows); 26 is unchanged.
# Pooled over agencies with 3+ won programs in each window's pool, as in 21 and 26.

here::i_am("src/R/27_intime_curve.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "helpers_rank.R"))
source(here::here("src", "R", "score.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(stringr) })

amap <- read_csv(file.path(DIR_MANUAL, "agency_award_map.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
confirmed <- amap |> filter(certainty == "confirmed", !is.na(agency_id), agency_id != "")
awards <- read_csv(file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv"), show_col_types = FALSE,
                   col_types = cols(cfda = col_character(), recipient = col_character(), .default = col_guess()))
won <- inner_join(awards, confirmed |> select(recipient, agency_id), by = "recipient") |> distinct(agency_id, cfda)

cr <- read_criteria(); inp <- load_rank_inputs()
closed <- inp$opps |> filter(status == "closed", !is.na(close_date) | !is.na(date_note))
raw <- read_csv(OPPS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
closed$close_date <- as.Date(raw$close_date[match(closed$opp_id, raw$opp_id)])
closed <- closed |> filter(!is.na(close_date), close_date >= CLOSED_SINCE, close_date <= REF_DATE,
                           !is.na(post_date), close_date < FAR_FUTURE_DATE)
items <- build_items(closed, inp$ag, inp$plans, inp$pmap)
items$close_date <- as.Date(closed$close_date[match(items$opp_id, closed$opp_id)])
rk <- rank_by_agency(items, cr)$ranked
rk <- left_join(rk, items[, c("id", "opp_id", "post_date", "close_date")], by = "id") |>
  left_join(distinct(inp$opps[, c("opp_id", "cfda_list", "title")]), by = "opp_id") |>
  filter(agency_id %in% unique(won$agency_id), !is.na(cfda_list), cfda_list != "")

curve <- bind_rows(lapply(WINDOW_WEEKS, function(w) {
  start <- seq(CLOSED_SINCE, REF_DATE, by = 7 * w)
  grid <- tibble(window_start = start, window_end = start + 7 * w - 1) |> filter(window_end <= REF_DATE)
  pool <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
    g <- grid[g, ]
    rk |> filter(post_date <= g$window_end, close_date >= g$window_start) |>
      group_by(agency_id) |> mutate(m_rank = rank(-total, ties.method = "first"), pool_n = n()) |> ungroup() |>
      transmute(agency_id, window_start = g$window_start, window_end = g$window_end, opp_id, title, cfda_list,
                total, passed, m_rank, pool_n, days_left = as.integer(close_date - g$window_end))
  })) |> separate_longer_delim(cfda_list, delim = "|") |> mutate(cfda = trimws(cfda_list)) |> filter(cfda != "")
  
  prog <- pool |> inner_join(won, by = c("agency_id", "cfda")) |> group_by(agency_id, cfda) |>
    summarise(caught = any(m_rank <= 10), caught_intime = any(m_rank <= 10 & days_left >= IN_TIME_DAYS), .groups = "drop") |>
    group_by(agency_id) |> filter(n() >= 3) |> ungroup()
  tibble(window_weeks = w, agencies = n_distinct(prog$agency_id), won = nrow(prog), caught = sum(prog$caught), caught_intime = sum(prog$caught_intime))
}))
curve <- curve |> mutate(pct = round(caught / won, 4), pct_intime = round(caught_intime / won, 4), in_time_days = IN_TIME_DAYS)
write_csv(curve, file.path(DIR_PROCESSED, "backtest_v2_intime_curve.csv"))
print(as.data.frame(curve))
message("In time means at least ", IN_TIME_DAYS, " days left at the window end (team assumption). Program-level match favors repeat funding.")

# 24_backtest_misses.R: for each won program that did not reach the v2 Top 10, where did it sit? (task E2)
# Run from Finalists/src: Rscript R/24_backtest_misses.R   Offline; reads only; writes data/processed/backtest_misses.csv.
# Rebuilds the same full pool as 21_backtest_v2.R (4-week windows only) because that file does not save it.
# Same agencies, window grid, ranking and "won" definition as 21; nothing from 21 or score.R is edited.
# Cause labels are descriptive, from the stored rank, not proven causes. Program-level match favors repeat funding.

here::i_am("src/R/24_backtest_misses.R")
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

w <- 4L
start <- seq(CLOSED_SINCE, REF_DATE, by = 7 * w)
grid <- tibble(window_start = start, window_end = start + 7 * w - 1) |> filter(window_end <= REF_DATE)
pool <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
  g <- grid[g, ]
  rk |> filter(post_date <= g$window_end, close_date >= g$window_start) |>
    group_by(agency_id) |> mutate(m_rank = rank(-total, ties.method = "first"), pool_n = n()) |> ungroup() |>
    transmute(agency_id, window_start = g$window_start, window_end = g$window_end, opp_id, title, cfda_list,
              total, passed, m_rank, pool_n, days_left = as.integer(close_date - g$window_end))
})) |> separate_longer_delim(cfda_list, delim = "|") |> mutate(cfda = trimws(cfda_list)) |> filter(cfda != "")

best <- pool |> inner_join(won, by = c("agency_id", "cfda")) |>
  group_by(agency_id, cfda) |> arrange(m_rank, .by_group = TRUE) |>
  summarise(windows_with_notice = n_distinct(window_start), best_rank = first(m_rank), pool_at_best = first(pool_n),
            best_total = first(total), best_passed = first(passed), days_left_at_best = first(days_left),
            best_title = first(title), .groups = "drop") |>
  mutate(group = case_when(best_rank <= 10 ~ "reached Top 10",
                           best_rank <= 50 ~ "rank 11 to 50",
                           is.na(best_total) | !best_passed ~ "dropped by a gate",
                           TRUE ~ "rank below 50"))
write_csv(best, file.path(DIR_PROCESSED, "backtest_misses.csv"), na = "")
big <- best |> group_by(agency_id) |> filter(n() >= 3) |> ungroup()
message("Won programs with a notice in the pool, 4-week, agencies with 3+: ", nrow(big))
print(big |> count(group)); print(big |> count(agency_id, group) |> tidyr::pivot_wider(names_from = group, values_from = n, values_fill = 0))
print(big |> filter(group != "reached Top 10") |> summarise(median_best_rank = median(best_rank), median_pool = median(pool_at_best)))

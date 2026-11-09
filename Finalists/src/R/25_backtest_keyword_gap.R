# 25_backtest_keyword_gap.R: for won programs that sat "rank below 50" (24_backtest_misses.R), test whether
# the notice shares few plan words with its agency (consistent with a keyword gap). Task E4.
# Run from Finalists/src: Rscript R/25_backtest_keyword_gap.R   Offline; reads only; writes data/processed/backtest_keyword_gap.csv.
# Same pool as 24 (4-week windows). "Consistent with" is a description, not a proven cause.

here::i_am("src/R/25_backtest_keyword_gap.R")
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
rk <- left_join(rk[, setdiff(names(rk), "fit")], items[, c("id", "opp_id", "post_date", "close_date", "fit")], by = "id") |>
  left_join(distinct(inp$opps[, c("opp_id", "cfda_list", "title", "opp_text")]), by = "opp_id", suffix = c("", ".o")) |>
  filter(agency_id %in% unique(won$agency_id), !is.na(cfda_list), cfda_list != "")

w <- 4L
start <- seq(CLOSED_SINCE, REF_DATE, by = 7 * w)
grid <- tibble(window_start = start, window_end = start + 7 * w - 1) |> filter(window_end <= REF_DATE)
pool <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
  g <- grid[g, ]
  rk |> filter(post_date <= g$window_end, close_date >= g$window_start) |>
    group_by(agency_id) |> mutate(m_rank = rank(-total, ties.method = "first"), pool_n = n(),
                                  top10_median_fit = median(fit[m_rank <= TOP10_N])) |> ungroup() |>
    transmute(agency_id, window_start = g$window_start, opp_id, title, opp_text, cfda_list, fit, top10_median_fit,
              total, passed, m_rank, pool_n)
})) |> separate_longer_delim(cfda_list, delim = "|") |> mutate(cfda = trimws(cfda_list)) |> filter(cfda != "")

best <- pool |> inner_join(won, by = c("agency_id", "cfda")) |>
  group_by(agency_id, cfda) |> arrange(m_rank, .by_group = TRUE) |>
  summarise(best_rank = first(m_rank), best_total = first(total), best_passed = first(passed), best_title = first(title),
            opp_text = first(opp_text), fit = first(fit), top10_median_fit = first(top10_median_fit), .groups = "drop") |>
  mutate(group = case_when(best_rank <= TOP10_N ~ "reached Top 10",
                           best_rank <= BACKTEST_TOP_N ~ "rank 11 to 50",
                           is.na(best_total) | !best_passed ~ "dropped by a gate",
                           TRUE ~ "rank below 50"))
big <- best |> group_by(agency_id) |> filter(n() >= 3) |> ungroup() |> filter(group == "rank below 50")

plan_tok <- lapply(inp$plans, function(p) kw_tokenize(p)[[1]])
res <- lapply(seq_len(nrow(big)), function(i) {
  r <- big[i, ]
  ot <- unique(kw_tokenize(r$opp_text)[[1]]); pt <- plan_tok[[r$agency_id]]
  shared <- intersect(ot, pt)
  cnt <- sort(table(pt[pt %in% shared]), decreasing = TRUE)
  cnt <- cnt[order(-as.integer(cnt), names(cnt))]
  tibble(n_notice_tokens = length(ot), n_shared_tokens = length(shared),
         shared_share = if (length(ot)) length(shared) / length(ot) else NA_real_,
         top_shared_words = paste(head(names(cnt), N_TOP), collapse = " "))
})
out <- bind_cols(big |> select(agency_id, cfda, group, best_rank, best_title, fit, top10_median_fit), bind_rows(res)) |>
  mutate(fit_minus_top10_median = fit - top10_median_fit,
         fit_below_top10_median = fit < top10_median_fit) |>
  arrange(agency_id, cfda)
idx <- unique(round(seq(1, nrow(out), length.out = min(TOP10_N, nrow(out)))))
out$hand_tag_sample <- seq_len(nrow(out)) %in% idx
write_csv(out |> mutate(across(where(is.double), \(x) round(x, 4))),
          file.path(DIR_PROCESSED, "backtest_keyword_gap.csv"), na = "")

message("rank-below-50 programs (agencies with 3+): ", nrow(out))
print(out |> summarise(below_top10_median = sum(fit_below_top10_median), zero_fit = sum(fit == 0),
                       median_fit = median(fit), median_top10_fit = median(top10_median_fit),
                       median_shared = median(n_shared_tokens), median_share = median(shared_share, na.rm = TRUE)))
print(out |> count(agency_id, name = "n"), n = Inf)

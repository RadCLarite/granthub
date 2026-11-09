# 21_backtest_v2.R: award-history backtest, step 1 "fix the measure". Exploratory, not the pre-set bar.
# Run from Finalists/src: Rscript R/21_backtest_v2.R
#
# Why v2: 20_backtest_awards.R counts a won program only if it shows up in the stored top 50, so recall at any
# N is inflated and N cannot be widened (everything in the denominator is already top 50). Here the denominator
# is every won program that has an open notice in the agency's FULL pool for that window, and recall is the
# share of those that reach the Top N. Baselines use the same pool: soonest deadline first, and the exact
# expected value of a random N (hypergeometric). Same window grid and ranking as 12_backtest.R.
#
# What stays fixed: 20_backtest_awards.R and its failed 50% bar are untouched and still reported. This file
# adds more agencies (exact-name state agency rows in agency_award_map.csv), Top 10/20/50, and a flag for
# agencies at or above 50%. The 50% line is the same team judgment; here it is descriptive, not a new bar.
# Notice-level match is NOT possible: the award data (nc_awards_by_cfda.csv) has no link to a notice.
# Reach (bonus 1): newest-posted-first stands in for a new-postings alert, the usual manual monitoring; only_model
# counts won programs our Top N caught that the alert Top N did not.
# Limit beside every result: program-level match favors repeat funding; award data never enters the score.

here::i_am("src/R/21_backtest_v2.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "helpers_rank.R"))
source(here::here("src", "R", "score.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(stringr) })

AWARD_MAP_FILE   <- file.path(DIR_MANUAL, "agency_award_map.csv")
AWARDS_CFDB_FILE <- file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv")
RESULT_V2_FILE   <- file.path(DIR_PROCESSED, "backtest_v2_result.csv")
TOP_NS           <- c(10L, 20L, 50L)
PASS_PCT         <- 0.50   # same team judgment as 20_backtest_awards.R; descriptive here

# ---- won programs per agency (confirmed recipients only) -------------------------------------
amap <- read_csv(AWARD_MAP_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
confirmed <- amap |> filter(certainty == "confirmed", !is.na(agency_id), agency_id != "")
awards <- read_csv(AWARDS_CFDB_FILE, show_col_types = FALSE, col_types = cols(cfda = col_character(), recipient = col_character(), .default = col_guess()))
won <- inner_join(awards, confirmed |> select(recipient, agency_id), by = "recipient") |> distinct(agency_id, cfda)
message("Agencies with a confirmed award map: ", paste(sort(unique(won$agency_id)), collapse = ", "))

# ---- rank every closed item per window (same as 12_backtest.R, but keep the full pool) -------
cr <- read_criteria()
inp <- load_rank_inputs()
closed <- inp$opps |> filter(status == "closed", !is.na(close_date) | !is.na(date_note))
raw <- read_csv(OPPS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
closed$close_date <- as.Date(raw$close_date[match(closed$opp_id, raw$opp_id)])
closed <- closed |> filter(!is.na(close_date), close_date >= CLOSED_SINCE, close_date <= REF_DATE,
                           !is.na(post_date), close_date < FAR_FUTURE_DATE)
items <- build_items(closed, inp$ag, inp$plans, inp$pmap)
items$close_date <- as.Date(closed$close_date[match(items$opp_id, closed$opp_id)])
rk <- rank_by_agency(items, cr)$ranked
rk <- left_join(rk, items[, c("id", "opp_id", "post_date", "close_date")], by = "id") |>
  left_join(distinct(inp$opps[, c("opp_id", "cfda_list")]), by = "opp_id") |>
  filter(agency_id %in% unique(won$agency_id), !is.na(cfda_list), cfda_list != "")

grid <- bind_rows(lapply(WINDOW_WEEKS, function(w) {
  start <- seq(CLOSED_SINCE, REF_DATE, by = 7 * w)
  tibble(window_weeks = w, window_start = start, window_end = start + 7 * w - 1)
})) |> filter(window_end <= REF_DATE)

# One row per agency, window, notice with its model rank and deadline rank in the full pool.
pool <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
  w <- grid[g, ]
  rk |> filter(post_date <= w$window_end, close_date >= w$window_start) |>
    group_by(agency_id) |>
    mutate(m_rank = rank(-total, ties.method = "first"), d_rank = rank(close_date, ties.method = "first"),
           n_rank = rank(-as.numeric(post_date), ties.method = "first"),   # newest posted first (a new-postings alert)
           pool_n = n()) |>
    ungroup() |>
    transmute(agency_id, window_weeks = w$window_weeks, window_start = w$window_start, opp_id, cfda_list, m_rank, d_rank, n_rank, pool_n)
}))
pool <- pool |> separate_longer_delim(cfda_list, delim = "|") |> mutate(cfda = trimws(cfda_list)) |> filter(cfda != "")
message("Pool rows (notice x program x window): ", nrow(pool))

# ---- recall: a won program counts as caught if it reaches the Top N in at least one window ----
binom_ci <- function(k, n) if (n == 0) c(NA_real_, NA_real_) else binom.test(k, n)$conf.int
calc <- function(ag, wk, N) {
  p <- pool |> filter(agency_id == ag, window_weeks == wk, cfda %in% won$cfda[won$agency_id == ag])
  if (nrow(p) == 0) return(NULL)
  per_prog <- p |> group_by(cfda) |>
    summarise(model = any(m_rank <= N), deadline = any(d_rank <= N), newest = any(n_rank <= N), .groups = "drop") |> as.data.frame()
  # Random baseline: chance a random N catches the program in a window is 1 - P(no draw of its k notices);
  # combined over windows as 1 - prod(1 - p).
  per_win <- p |> group_by(cfda, window_start) |> summarise(k = n(), M = first(pool_n), .groups = "drop") |>
    mutate(pr = 1 - phyper(0, k, M - k, pmin(N, M))) |> group_by(cfda) |> summarise(rand = 1 - prod(1 - pr), .groups = "drop")
  per_prog$rand <- per_win$rand[match(per_prog$cfda, per_win$cfda)]
  n <- nrow(per_prog); k <- sum(per_prog$model); ci <- binom_ci(k, n)
  tibble(agency_id = ag, window_weeks = wk, top_n = N, won_in_pool = n, caught = k, pct = k / n,
         ci_low = ci[1], ci_high = ci[2], deadline_pct = mean(per_prog$deadline), random_pct = mean(per_prog$rand),
         newest_pct = mean(per_prog$newest), only_model = sum(per_prog$model & !per_prog$newest),
         only_newest = sum(per_prog$newest & !per_prog$model),
         median_pool = median(unique(p[c("window_start", "pool_n")])$pool_n))
}
combos <- expand.grid(ag = sort(unique(won$agency_id)), wk = WINDOW_WEEKS, N = TOP_NS, stringsAsFactors = FALSE)
res <- bind_rows(lapply(seq_len(nrow(combos)), function(i) calc(combos$ag[i], combos$wk[i], combos$N[i])))
res <- res |> arrange(window_weeks, top_n, agency_id)
write_csv(res, RESULT_V2_FILE, na = "")
message("Wrote ", RESULT_V2_FILE, " (", nrow(res), " rows)")

four <- res |> filter(window_weeks == 4)
for (N in TOP_NS) {
  s <- four |> filter(top_n == N, won_in_pool >= 3)
  message("4-week, Top ", N, ": ", sum(s$pct >= PASS_PCT), " of ", nrow(s), " agencies (3+ won programs) at or above ",
          PASS_PCT * 100, "%; deadline sort: ", sum(s$deadline_pct >= PASS_PCT), "; random: ", sum(s$random_pct >= PASS_PCT))
}
print(as.data.frame(four |> filter(top_n == 10) |> mutate(across(c(pct, ci_low, ci_high, deadline_pct, random_pct), \(x) round(x, 2)))))
message("Limit: program level match favors repeat funding; denominators are small; no notice-level award link exists.")

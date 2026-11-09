# 20_backtest_awards.R: award history backtest for DPI, DEQ and DHHS.
# Run from Finalists/src: Rscript R/20_backtest_awards.R
# Build against Kent's stub rankings_backtest.csv until he merges the real one at 11:00, then pull main and rerun.
# Pass bar is fixed. A failed bar is evidence, not something to rerun until it passes.
here::i_am("src/R/20_backtest_awards.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_report.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(stringr) })

# TODO move to 00_config.R
AWARD_MAP_FILE <- file.path(DIR_MANUAL, "agency_award_map.csv")
AWARDS_CFDB_FILE <- file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv")
RECIPIENTS_FILE <- file.path(DIR_PROCESSED, "nc_awards_recipients.csv")
RANKINGS_FILE <- file.path(DIR_PROCESSED, "rankings_backtest.csv")
RESULT_FILE <- file.path(DIR_PROCESSED, "backtest_result.csv")
FIGURE_NAME <- "backtest_recall"
AGENCIES <- c("dpi", "deq", "dhhs")  # fixed by pass bar, do not change after seeing results
PASS_PCT <- 0.50  # fixed team judgment, not derived. Do not change after seeing results.

# Award data never goes into the ranking score. This script only reads rankings_backtest.csv as scored by Kent.
# Wording: we say "would have flagged" and "programs this agency has won", never "missed".
# We report by agency, not one statewide number.
# Limit: program level match favors repeat funding. State that limit beside every result.

amap <- read_csv(AWARD_MAP_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
confirmed <- amap |> filter(certainty == "confirmed", !is.na(agency_id), agency_id != "")
uncertain <- amap |> filter(certainty != "confirmed")
message("Award map: ", nrow(confirmed), " confirmed recipients, ", nrow(uncertain), " uncertain or excluded. Every uncertain recipient is listed in agency_award_map.csv.")
if (nrow(uncertain) > 0) {
  for (i in seq_len(nrow(uncertain))) {
    message("  [", uncertain$certainty[i], "] ", uncertain$recipient[i], " -> ", ifelse(is.na(uncertain$agency_id[i]) | uncertain$agency_id[i] == "", "(no agency)", uncertain$agency_id[i]))
  }
}

awards <- read_csv(AWARDS_CFDB_FILE, show_col_types = FALSE, col_types = cols(cfda = col_character(), recipient = col_character(), .default = col_guess()))
# Only confirmed recipients count toward programs this agency has won.
won <- awards |> inner_join(confirmed |> select(recipient, agency_id), by = "recipient")
# Won programs per agency (all that agency has won in FY2022-2026)
uniq_won <- unique(won[, c("agency_id", "cfda")])
won_sets <- split(uniq_won$cfda, uniq_won$agency_id)
for (a in AGENCIES) {
  ws <- won_sets[[a]]
  if (is.null(ws)) ws <- character(0)
  message(a, ": ", length(ws), " distinct CFDA programs this agency has won in nc_awards_by_cfda.csv")
}

if (!file.exists(RANKINGS_FILE)) stop("not found: ", RANKINGS_FILE)
rankings <- read_csv(RANKINGS_FILE, show_col_types = FALSE,
                     col_types = cols(agency_id = col_character(), window_start = col_date(), window_end = col_date(),
                                      window_weeks = col_integer(), opp_id = col_character(), opp_number = col_character(),
                                      cfda_list = col_character(), close_date = col_date(), fit_score = col_double(), rank = col_integer()))
message("rankings_backtest.csv: ", nrow(rankings), " rows; agencies: ", paste(sort(unique(rankings$agency_id)), collapse = ", "), "; window_weeks: ", paste(sort(unique(rankings$window_weeks)), collapse = ", "))
# WARN: stub check. Stub has 5 DEQ 2-week rows only and fit_score is NA. Real file merges at 11:00. Do not put stub values on a slide.
if (all(is.na(rankings$fit_score)) && nrow(rankings) <= 10) {
  message("STUB WARNING: rankings_backtest.csv looks like Kent's stub (fit_score all NA, few rows). Build the script but do not publish stub numbers. Rerun after Merge 2 at 11:00.")
}

# Expand pipe separated CFDA list into one row per program
expand_cfda <- function(df) {
  df |> mutate(cfda_one = ifelse(is.na(cfda_list) | cfda_list == "", NA_character_, cfda_list)) |>
    filter(!is.na(cfda_one)) |>
    separate_longer_delim(cfda_one, delim = "|") |>
    mutate(cfda_one = trimws(cfda_one)) |>
    filter(cfda_one != "")
}
expanded <- expand_cfda(rankings)

# Binomial exact interval (Clopper-Pearson). NA when denominator is 0.
binom_ci <- function(k, n, conf = 0.95) {
  if (n == 0) return(c(low = NA_real_, high = NA_real_))
  ci <- binom.test(k, n, p = 0.5, conf.level = conf)$conf.int
  c(low = ci[1], high = ci[2])
}

calc_for <- function(ag, wk) {
  sub <- rankings |> filter(agency_id == ag, window_weeks == wk)
  sub_exp <- expanded |> filter(agency_id == ag, window_weeks == wk)
  won_set <- won_sets[[ag]]
  if (is.null(won_set)) won_set <- character(0)
  # Denominator: won programs that had an open notice in this agency+window_weeks (appear anywhere rank 1-50)
  present <- unique(sub_exp$cfda_one)
  eligible <- intersect(won_set, present)
  n_el <- length(eligible)
  n_caught <- 0L
  n_intime <- 0L
  base_dead <- 0L
  base_rand <- 0L
  if (n_el > 0 && nrow(sub) > 0) {
    # Model top 10
    top10_exp <- sub_exp |> filter(!is.na(rank), rank <= FLAG_TOP_N)
    caught_set <- intersect(unique(top10_exp$cfda_one), eligible)
    n_caught <- length(caught_set)
    # In time: at least IN_TIME_DAYS days remained before close at end of window
    intime_exp <- top10_exp |> filter(!is.na(close_date), !is.na(window_end), as.integer(close_date - window_end) >= IN_TIME_DAYS)
    n_intime <- length(intersect(unique(intime_exp$cfda_one), eligible))
    # Baseline deadline: soonest deadline first 10 rows per (window_start, window_end) window instance
    dead_sets <- list()
    rand_sets <- list()
    set.seed(POOL_SEED)
    for (w in unique(sub$window_start)) {
      grp <- sub |> filter(window_start == w) |> arrange(close_date, opp_id)
      grp_exp <- expand_cfda(grp)
      take_dead <- head(grp, 10)
      dead_sets[[as.character(w)]] <- unique(expand_cfda(take_dead)$cfda_one)
      # Random 10 from same window instance, fixed seed by POOL_SEED
      idx <- seq_len(nrow(grp))
      samp <- if (length(idx) <= 10) idx else sample(idx, 10, replace = FALSE)
      rand_sets[[as.character(w)]] <- unique(expand_cfda(grp[samp, ])$cfda_one)
    }
    base_dead <- length(intersect(eligible, unique(unlist(dead_sets))))
    base_rand <- length(intersect(eligible, unique(unlist(rand_sets))))
  }
  pct <- ifelse(n_el > 0, n_caught / n_el, NA_real_)
  intime_pct <- ifelse(n_el > 0, n_intime / n_el, NA_real_)
  ci <- binom_ci(n_caught, n_el)
  tibble(agency_id = ag, window_weeks = wk, won_programs = n_el, caught = n_caught,
         pct = pct, ci_low = ci[["low"]], ci_high = ci[["high"]],
         baseline_deadline_pct = ifelse(n_el > 0, base_dead / n_el, NA_real_),
         baseline_random_pct = ifelse(n_el > 0, base_rand / n_el, NA_real_),
         caught_intime = n_intime, pct_intime = intime_pct)
}

results <- bind_rows(lapply(AGENCIES, function(a) bind_rows(lapply(WINDOW_WEEKS, function(w) calc_for(a, w)))))
results <- results |> arrange(match(agency_id, AGENCIES), window_weeks)

dir.create(DIR_PROCESSED, showWarnings = FALSE, recursive = TRUE)
csv_out <- results |> select(agency_id, window_weeks, won_programs, caught, pct, ci_low, ci_high, baseline_deadline_pct, baseline_random_pct)
write_csv(csv_out, RESULT_FILE, na = "")
message("Wrote ", RESULT_FILE, " (", nrow(results), " rows)")
print(as.data.frame(results))

# Figure: by agency, x = window weeks, y = share would have flagged, two lines: all vs in-time. Never statewide.
# Limit caption: program level match favors repeat funding. Award data never goes into the ranking score.
plot_df <- results |>
  tidyr::pivot_longer(c(pct, pct_intime), names_to = "measure", values_to = "share") |>
  mutate(measure = ifelse(measure == "pct_intime", "intime", "all"),
         measure = factor(measure, levels = c("all", "intime")),
         agency_id = factor(agency_id, levels = AGENCIES))
# Only plot rows with data; stub will have NAs for DPI and DHHS and one DEQ point
if (all(is.na(plot_df$share))) {
  p <- ggplot(plot_df, aes(window_weeks, share)) + geom_blank() +
    labs(title = "Backtest recall by agency (stub) - no data yet",
         subtitle = "Share of programs this agency has won that the tool would have flagged in top 10. Program level match favors repeat funding. Award data never in score.",
         x = "Window weeks", y = "Share would have flagged") + theme_finals() +
    ggplot2::facet_wrap(~agency_id) + ggplot2::geom_hline(yintercept = PASS_PCT, linetype = "dashed")
} else {
  p <- ggplot(plot_df, aes(window_weeks, share, color = measure, group = measure)) +
    geom_line(aes(linetype = measure), linewidth = 0.6) + geom_point(size = 3) +
    geom_hline(yintercept = PASS_PCT, linetype = "dashed", color = "grey40") +
    ggplot2::scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    ggplot2::scale_color_manual(values = c("all" = FIG_COLORS$main, "intime" = FIG_COLORS$accent)) +
    ggplot2::scale_linetype_manual(values = c("all" = "solid", "intime" = "dashed")) +
    ggplot2::facet_wrap(~agency_id) +
    labs(title = "Backtest: would have flagged by agency",
         subtitle = "Share of programs this agency has won flagged in top 10. Lines: all catches, in-time (>=21 days before close). Dashed = 50% pass bar (team judgment). Program level match favors repeat funding; award data never in score.",
         x = "Window weeks", y = "Share would have flagged", color = NULL, linetype = NULL) +
    theme_finals() + theme(legend.position = "right")
}
export_figure(p, FIGURE_NAME, width = 9, height = 3.2)
message("Limit note: program level match favors repeat funding. Counts are programs, not exact notices. Report by agency.")
message("Pass bar (fixed, set before run): at least 50% per agency on 4-week windows, pass if 2 of 3. Do not change after seeing results. A failed bar is evidence for field notes.")

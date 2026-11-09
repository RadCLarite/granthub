# 22_backtest_tune.R: backtest step 2. Try a small grid of text-fit variants and check them on held-out agencies.
# Run from Finalists/src: Rscript R/22_backtest_tune.R   (about 5 minutes)
#
# LABEL: this is tuning AFTER seeing the first backtest. It does not replace the pre-set bar in
# 20_backtest_awards.R (that failed and stays reported). Award data is used only to CHOOSE among
# text settings here; it never enters the score in the shipped pipeline.
#
# Design: 12 agencies with 3+ won programs (same set as 21_backtest_v2.R), 4-week windows, Top 10 recall on the
# full window pool. The agencies are split into two folds (alternating by name). Pick the setting that does best
# on one fold, report it on the OTHER fold, then swap. A setting is adopted only if it beats the current
# setting on the held-out folds in BOTH directions. Leave-one-program-out was not used: the settings are global
# text choices, so holding out whole agencies is the stricter test.
# Grid (all text, no award data): title repeated 1, 2 or 3 times in the opportunity text;
# centering of fit across agencies: "mean" (current), "none", "z" (divide by the spread across agencies).

here::i_am("src/R/22_backtest_tune.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "helpers_rank.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(stringr) })

TUNE_RESULT_FILE <- file.path(DIR_PROCESSED, "backtest_tune_result.csv")
TOP_N <- FLAG_TOP_N
WK <- 4L

amap <- read_csv(file.path(DIR_MANUAL, "agency_award_map.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
confirmed <- amap |> filter(certainty == "confirmed", !is.na(agency_id), agency_id != "")
awards <- read_csv(file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv"), show_col_types = FALSE,
                   col_types = cols(cfda = col_character(), recipient = col_character(), .default = col_guess()))
won <- inner_join(awards, confirmed |> select(recipient, agency_id), by = "recipient") |> distinct(agency_id, cfda)
agencies <- sort(unique(won$agency_id))

inp <- load_rank_inputs()
closed <- inp$opps |> filter(status == "closed", !is.na(close_date) | !is.na(date_note))
raw <- read_csv(OPPS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
closed$close_date <- as.Date(raw$close_date[match(closed$opp_id, raw$opp_id)])
closed <- closed |> filter(!is.na(close_date), close_date >= CLOSED_SINCE, close_date <= REF_DATE,
                           !is.na(post_date), close_date < FAR_FUTURE_DATE)
cfda_of <- distinct(inp$opps[, c("opp_id", "cfda_list")])
grid <- tibble(window_start = seq(CLOSED_SINCE, REF_DATE, by = 7 * WK)) |>
  mutate(window_end = window_start + 7 * WK - 1) |> filter(window_end <= REF_DATE)

# Variant of build_pairs(): same as helpers_rank.R except the two settings below. build_items() looks it up globally.
TITLE_REP <- 1L; CENTER <- "mean"
build_pairs <- function(opps, ag, plans, fit_fn = keyword_fit) {
  txt <- paste(strrep(paste0(opps$title, " "), TITLE_REP), ifelse(is.na(opps$summary), "", opps$summary))
  sim <- fit_fn(txt, plans); colnames(sim) <- names(plans)
  cen <- switch(CENTER, mean = sim - rowMeans(sim), none = sim,
                z = { s <- apply(sim, 1, sd); s[s == 0] <- 1; (sim - rowMeans(sim)) / s })
  gsim <- fit_fn(txt, ag$goal_text)
  bind_rows(lapply(names(plans), function(a) {
    raw <- pmax(cen[, a], 0); top <- max(raw); cols <- which(ag$agency_id == a)
    gs <- gsim[, cols, drop = FALSE]; best <- max.col(gs, ties.method = "first")
    has <- gs[cbind(seq_len(nrow(gs)), best)] > 0
    tibble(agency_id = a, opp_id = opps$opp_id, fit_raw = cen[, a], fit = if (top > 0) raw / top else 0,
           goal_id = ifelse(has, ag$goal_id[cols[best]], NA), goal_snippet = ifelse(has, ag$goal_text_exact[cols[best]], NA))
  }))
}

eval_config <- function(title_rep, center) {
  TITLE_REP <<- title_rep; CENTER <<- center
  it <- build_items(closed, inp$ag, inp$plans, inp$pmap)
  it$close_date <- as.Date(closed$close_date[match(it$opp_id, closed$opp_id)])
  it <- it |> filter(eligibility != "no", agency_id %in% agencies) |>
    left_join(cfda_of, by = "opp_id") |> filter(!is.na(cfda_list), cfda_list != "")
  pool <- bind_rows(lapply(seq_len(nrow(grid)), function(g) {
    w <- grid[g, ]
    it |> filter(post_date <= w$window_end, close_date >= w$window_start) |>
      group_by(agency_id) |> mutate(m_rank = rank(-fit, ties.method = "first")) |> ungroup() |>
      transmute(agency_id, opp_id, cfda_list, m_rank)
  }))
  pool |> separate_longer_delim(cfda_list, delim = "|") |> mutate(cfda = trimws(cfda_list)) |>
    inner_join(won, by = c("agency_id", "cfda")) |>
    group_by(agency_id, cfda) |> summarise(caught = any(m_rank <= TOP_N), .groups = "drop") |>
    group_by(agency_id) |> summarise(won_in_pool = n(), caught = sum(caught), .groups = "drop")
}

cfgs <- expand.grid(title_rep = 1:3, center = c("mean", "none", "z"), stringsAsFactors = FALSE)
res <- bind_rows(lapply(seq_len(nrow(cfgs)), function(i) {
  message("config ", i, "/", nrow(cfgs), ": title x", cfgs$title_rep[i], ", centering ", cfgs$center[i])
  mutate(eval_config(cfgs$title_rep[i], cfgs$center[i]), title_rep = cfgs$title_rep[i], center = cfgs$center[i])
}))
use <- res |> group_by(agency_id) |> filter(first(won_in_pool) >= 3) |> ungroup()
ag12 <- sort(unique(use$agency_id))
use$fold <- ifelse(match(use$agency_id, ag12) %% 2 == 1, "A", "B")
write_csv(use, TUNE_RESULT_FILE)

by_fold <- use |> group_by(title_rep, center, fold) |>
  summarise(won = sum(won_in_pool), caught = sum(caught), recall = caught / won, .groups = "drop")
tot <- use |> group_by(title_rep, center) |> summarise(won = sum(won_in_pool), caught = sum(caught), recall = caught / won, .groups = "drop")
message("\nAll 12 agencies:"); print(as.data.frame(tot |> arrange(desc(recall)) |> mutate(recall = round(recall, 3))))
base <- by_fold |> filter(title_rep == 1, center == "mean")
for (tr in c("A", "B")) {
  te <- ifelse(tr == "A", "B", "A")
  best <- by_fold |> filter(fold == tr) |> arrange(desc(recall)) |> slice(1)
  hold <- by_fold |> filter(fold == te, title_rep == best$title_rep, center == best$center)
  message("Pick on fold ", tr, ": title x", best$title_rep, ", ", best$center, " (train recall ", round(best$recall, 3),
          " vs current ", round(base$recall[base$fold == tr], 3), "). Held-out fold ", te, ": ", hold$caught, " of ", hold$won,
          " (", round(hold$recall, 3), ") vs current ", base$caught[base$fold == te], " of ", base$won[base$fold == te],
          " (", round(base$recall[base$fold == te], 3), ")")
}

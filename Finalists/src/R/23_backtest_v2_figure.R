# 23_backtest_v2_figure.R: figures for the v2 award backtest (task E1). Reads only; edits no other file.
# Run from Finalists/src: Rscript R/23_backtest_v2_figure.R
# Input:  data/processed/backtest_v2_result.csv (written by 21_backtest_v2.R)
# Output: outs/figures/backtest_v2_pooled.png, backtest_v2_by_agency.png
#
# Pooling matches fact sheet rows 26 to 29: weight each agency by its won programs, 4-week windows,
# agencies with 3+ won programs. Random is the exact expected value from 21_backtest_v2.R.
# In-time catches live in 26_backtest_v2_intime.R (figure 3 below); 21_backtest_v2.R is unchanged.
# Only Top 10 (58 of 159, 36%), Top 50 (97 of 159, 61%) and the Top 10 baselines (17%, 13 or 14%) are in the fact sheet (rows 26 to 29).
# The Top 20 bars, the Top 50 baselines and the in-time counts are NOT in the fact sheet: do not speak them until Kent adds them.
# Limits (printed on the figures): exploratory, not the pre-set bar; program-level match favors repeat
# funding; award data never enters the score; small denominators; no notice-level award link exists.

here::i_am("src/R/23_backtest_v2_figure.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_report.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr); library(ggplot2) })

res <- read_csv(file.path(DIR_PROCESSED, "backtest_v2_result.csv"), show_col_types = FALSE)
four <- res |> filter(window_weeks == 4, won_in_pool >= 3)
caption <- "Exploratory, not the pre-set bar. Program-level match favors repeat funding; award data never enters the score."

# ---- Figure 1: pooled recall at Top 10 / 20 / 50, model vs soonest-deadline vs random ----------
pooled <- four |> group_by(top_n) |>
  summarise(n_prog = sum(won_in_pool), model = sum(caught) / sum(won_in_pool),
            deadline = sum(deadline_pct * won_in_pool) / sum(won_in_pool),
            random = sum(random_pct * won_in_pool) / sum(won_in_pool), .groups = "drop")
print(as.data.frame(pooled |> mutate(across(c(model, deadline, random), \(x) round(x, 3)))))
long <- pooled |> pivot_longer(c(model, deadline, random), names_to = "method", values_to = "share") |>
  mutate(method = factor(method, levels = c("model", "deadline", "random"),
                         labels = c("Tool ranking", "Soonest deadline", "Random")),
         top_n = factor(top_n, labels = paste("Top", sort(unique(pooled$top_n)))))
p1 <- ggplot(long, aes(top_n, share, fill = method)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  geom_text(aes(label = scales::percent(share, accuracy = 1)), position = position_dodge(width = 0.75),
            vjust = -0.4, size = 3.8) +
  scale_fill_manual(values = c("Tool ranking" = FIG_COLORS$main, "Soonest deadline" = FIG_COLORS$muted,
                               "Random" = FIG_COLORS$accent)) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "Would the tool have surfaced programs NC agencies won?",
       subtitle = paste0("Share of ", pooled$n_prog[1], " won programs (12 agencies with 3+, 4-week windows) that reach the list"),
       x = NULL, y = "Won programs reached", fill = NULL, caption = caption) +
  theme_finals() + theme(legend.position = "bottom")
export_figure(p1, "backtest_v2_pooled", width = 9, height = 5)

# ---- Figure 2: by agency, Top 10, with 95% interval and the two baselines ------------------------
a10 <- four |> filter(top_n == 10) |>
  mutate(lab = paste0(toupper(agency_id), " (", caught, "/", won_in_pool, ")"),
         lab = factor(lab, levels = lab[order(pct)]))
p2 <- ggplot(a10, aes(y = lab)) +
  geom_linerange(aes(xmin = ci_low, xmax = ci_high), color = FIG_COLORS$muted, linewidth = 1.2) +
  geom_point(aes(x = pct, color = "Tool ranking"), size = 3.5) +
  geom_point(aes(x = deadline_pct, color = "Soonest deadline"), shape = 15, size = 2.5) +
  geom_point(aes(x = random_pct, color = "Random"), shape = 17, size = 2.5) +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c("Tool ranking" = FIG_COLORS$main, "Soonest deadline" = "grey35",
                                "Random" = FIG_COLORS$accent)) +
  scale_x_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "By agency, Top 10, 4-week windows",
       subtitle = "Label = programs reached / won. Bar = 95% interval on the tool.\nDashed = 50% line (team judgment). Not a statewide number.",
       x = "Won programs reached", y = NULL, color = NULL, caption = caption) +
  theme_finals() + theme(legend.position = "bottom")
export_figure(p2, "backtest_v2_by_agency", width = 9, height = 5.5)
message("Limit: small denominators (1 to 38 programs per agency); intervals are wide. In-time figure needs 26_backtest_v2_intime.R output.")

# ---- Figure 3: Top 10 catches, all vs in time (>= IN_TIME_DAYS before close). Needs 26_backtest_v2_intime.R output ----
it_file <- file.path(DIR_PROCESSED, "backtest_v2_intime.csv")
if (file.exists(it_file)) {
  it <- read_csv(it_file, show_col_types = FALSE) |> group_by(agency_id) |> filter(n() >= 3) |>
    summarise(won = n(), all = sum(caught), in_time = sum(caught_intime), .groups = "drop") |>
    mutate(lab = factor(paste0(toupper(agency_id), " (", won, " won)"), levels = paste0(toupper(agency_id), " (", won, " won)")[order(all / won)]))
  tot <- it |> summarise(won = sum(won), all = sum(all), in_time = sum(in_time))
  long3 <- it |> pivot_longer(c(all, in_time), names_to = "m", values_to = "k") |>
    mutate(share = k / won, m = factor(m, levels = c("all", "in_time"), labels = c("Reached Top 10", paste0("... with ", IN_TIME_DAYS, "+ days left"))))
  p3 <- ggplot(long3, aes(share, lab, fill = m)) + geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    scale_fill_manual(values = c(FIG_COLORS$main, FIG_COLORS$accent)) +
    scale_x_continuous(limits = c(0, 1), labels = scales::percent) +
    labs(title = "How many catches left time to apply?",
         subtitle = paste0("Pooled: ", tot$all, " of ", tot$won, " reach the Top 10; ", tot$in_time, " with ", IN_TIME_DAYS,
                           "+ days left.\n(", IN_TIME_DAYS, " days is a team assumption; days counted from the window end.)"),
         x = "Share of won programs", y = NULL, fill = NULL, caption = caption) +
    theme_finals() + theme(legend.position = "bottom")
  export_figure(p3, "backtest_v2_intime", width = 9, height = 5.5)
} else message("No backtest_v2_intime.csv; run 26_backtest_v2_intime.R for the in-time figure.")

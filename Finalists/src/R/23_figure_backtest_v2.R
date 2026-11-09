# 23_figure_backtest_v2.R: slide figure for the v2 award backtest (exploratory). Reads backtest_v2_result.csv.
# Share of won programs reaching Top 10/20/50, ranking vs soonest-deadline sort vs random N, pooled over the 12
# agencies with 3+ won programs, 4-week windows. Run from Finalists/src: Rscript R/23_figure_backtest_v2.R
here::i_am("src/R/23_figure_backtest_v2.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_report.R"))
suppressPackageStartupMessages({ library(readr); library(dplyr); library(tidyr) })
r <- read_csv(file.path(DIR_PROCESSED, "backtest_v2_result.csv"), show_col_types = FALSE) |>
  filter(window_weeks == 4, won_in_pool >= 3)
d <- r |> group_by(top_n) |>
  summarise(Ranking = sum(caught) / sum(won_in_pool),
            `Soonest deadline` = sum(deadline_pct * won_in_pool) / sum(won_in_pool),
            `Random` = sum(random_pct * won_in_pool) / sum(won_in_pool), .groups = "drop") |>
  pivot_longer(-top_n, names_to = "method", values_to = "share") |>
  mutate(method = factor(method, levels = c("Ranking", "Soonest deadline", "Random")),
         top = factor(paste("Top", top_n), levels = paste("Top", sort(unique(top_n)))))
n_won <- sum(r$won_in_pool[r$top_n == min(r$top_n)]); n_ag <- n_distinct(r$agency_id)
p <- ggplot(d, aes(top, share, fill = method)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = scales::percent(share, accuracy = 1)), position = position_dodge(width = 0.8), vjust = -0.4, size = 4.2, color = "#222222") +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40") +
  annotate("text", x = 0.55, y = 0.545, label = "50% line (team judgment)", hjust = 0, size = 3.6, color = "grey30") +
  scale_fill_manual(values = c(Ranking = FIG_COLORS$main, `Soonest deadline` = FIG_COLORS$muted, Random = FIG_COLORS$accent)) +
  scale_y_continuous(limits = c(0, 0.75), labels = scales::percent) +
  labs(title = "Share of programs an agency has won that reach its Top N",
       subtitle = paste0(n_won, " won programs, ", n_ag, " agencies, 4-week windows.\nExploratory: the pre-set bar failed. Repeat funding favors this test.")) +
  theme_finals(13) + theme(legend.position = "top", legend.title = element_blank(), axis.title = element_blank())
export_figure(p, "backtest_recall_v2", width = 8, height = 4.5)

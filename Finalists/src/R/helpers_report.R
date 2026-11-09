# helpers_report.R: one chart style and one way to export figures for the slide brief.
# Requires 00_config.R. Figures land in outs/figures/ (the slide brief points at them).

suppressPackageStartupMessages({ library(ggplot2); library(dplyr) })

FIG_COLORS <- list(main = "#1F3A5F", muted = "#9AA5B1", accent = "#C8791B")

theme_finals <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          plot.title.position = "plot", plot.title = element_text(face = "bold"),
          axis.title = element_blank(), legend.position = "none")
}

# Horizontal bars of the ranked results, labeled directly.
plot_ranking <- function(ranked, n = 10, title = "Top results") {
  d <- ranked |> slice_head(n = n) |> mutate(name = factor(name, levels = rev(name)))
  ggplot(d, aes(total, name)) +
    geom_col(fill = FIG_COLORS$main, width = 0.7) +
    geom_text(aes(label = round(total)), hjust = -0.2, size = 4.2, color = FIG_COLORS$main) +
    scale_x_continuous(limits = c(0, 110), expand = c(0, 0)) +
    labs(title = title) + theme_finals()
}

export_figure <- function(p, name, width = 8, height = 4.5, dpi = 300) {
  dir.create(DIR_FIGS, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(DIR_FIGS, paste0(name, ".png"))
  ggsave(path, p, width = width, height = height, dpi = dpi, bg = "white")
  message("Wrote ", path)
  invisible(path)
}

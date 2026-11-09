# One-time setup: installs every R package the pipeline and notebook use.
# Run from anywhere:  Rscript src/install_packages.R
pkgs <- c(
  "arrow", "digest", "dplyr", "DT", "forcats", "ggplot2", "here", "htmltools",
  "htmlwidgets", "httr2", "janitor", "jsonlite", "knitr", "leaflet", "lubridate",
  "openxlsx", "pdftools", "readxl", "testthat", "plotly", "purrr", "readr", "rmapshaper", "rvest",
  "scales", "sf", "stringr", "takeaway", "tibble", "tidycensus", "tidyr", "tigris",
  "V8", "xml2"
)
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing) else message("All packages already installed.")

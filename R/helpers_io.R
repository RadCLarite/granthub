# helpers_io.R: read any file type, profile a table, fetch from an API with a cache.
# Requires 00_config.R. No side effects when sourced.

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(jsonlite); library(janitor)
  library(httr2); library(digest); library(purrr); library(tibble)
})

# One reader for the formats finals data usually arrives in. Column names are
# normalized to snake_case so downstream code can rely on them.
read_any <- function(path, sheet = NULL, ...) {
  ext <- tolower(tools::file_ext(path))
  out <- switch(ext,
    csv  = readr::read_csv(path, show_col_types = FALSE, ...),
    tsv  = readr::read_tsv(path, show_col_types = FALSE, ...),
    xlsx = ,
    xls  = readxl::read_excel(path, sheet = sheet %||% 1, ...),
    json = {
      x <- jsonlite::fromJSON(path, flatten = TRUE, ...)
      if (is.data.frame(x)) tibble::as_tibble(x) else x
    },
    rds  = readRDS(path),
    geojson = ,
    gpkg = ,
    shp  = sf::st_read(path, quiet = TRUE, ...),
    stop("Unsupported file type: .", ext)
  )
  if (is.data.frame(out) && !inherits(out, "sf")) out <- janitor::clean_names(out)
  out
}

excel_sheets <- function(path) readxl::excel_sheets(path)

# First look at a table: type, missingness, distinct values, range, examples.
# Run it on every raw file before deciding which fields can carry a criterion.
profile_data <- function(df) {
  if (inherits(df, "sf")) df <- sf::st_drop_geometry(df)
  purrr::imap_dfr(df, function(x, name) {
    nn <- x[!is.na(x)]
    rng <- if (is.numeric(x) || inherits(x, "Date")) paste(range(nn), collapse = " to ") else NA_character_
    tibble(column = name, type = class(x)[1], n = length(x),
           n_na = sum(is.na(x)), pct_na = round(100 * mean(is.na(x)), 1),
           n_distinct = dplyr::n_distinct(x), range = rng,
           examples = paste(utils::head(unique(as.character(nn)), 3), collapse = " | "))
  })
}

# ---- API fetch with a cache --------------------------------------------------------
# Every response is written to data/cache/api/<key>.<ext> (plus a .accessed stamp) and
# read from there on every later call, so a rerun never re-queries and never changes.
cached_fetch <- function(url, query = NULL, parse = c("json", "text", "raw"),
                         dir = DIR_CACHE_API, key = NULL, force = FALSE,
                         body = NULL, headers = NULL) {
  parse <- match.arg(parse)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  # body (a list) makes this a JSON POST and is part of the cache key. headers (for API
  # keys) are NOT part of the key and are never written to disk.
  key <- key %||% digest::digest(list(url, query, body), algo = "sha256")
  path <- file.path(dir, paste0(key, ".", if (parse == "json") "json" else "bin"))
  if (force || !file.exists(path)) {
    req <- httr2::request(url) |> httr2::req_user_agent("SolveAThon2026-student-team") |>
      httr2::req_retry(max_tries = 3)
    if (length(query)) req <- httr2::req_url_query(req, !!!query)
    if (length(headers)) req <- httr2::req_headers(req, !!!headers)
    if (!is.null(body)) req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
    if (exists("API_SLEEP_SEC")) Sys.sleep(API_SLEEP_SEC)
    resp <- httr2::req_perform(req)
    writeBin(httr2::resp_body_raw(resp), path)
    writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), paste0(path, ".accessed"))
  }
  switch(parse,
    json = jsonlite::fromJSON(path, simplifyVector = TRUE),
    text = paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    raw  = readBin(path, "raw", file.size(path)))
}

# Walk a paged API. `extract` turns one page's parsed JSON into a data frame; the walk
# stops at the first empty page or at max_pages.
fetch_paged <- function(url, query = list(), page_param = "page", first_page = 1L,
                        extract = function(x) tibble::as_tibble(x), max_pages = 50L) {
  pages <- list()
  for (i in seq_len(max_pages)) {
    q <- c(query, setNames(list(first_page + i - 1L), page_param))
    df <- extract(cached_fetch(url, q))
    if (is.null(df) || nrow(df) == 0) break
    pages[[i]] <- df
  }
  dplyr::bind_rows(pages)
}

# NC boundaries cached as RDS. Needs a network connection the first time only. [untested]
nc_boundaries <- function(level = c("county", "tract"), year = 2023) {
  level <- match.arg(level)
  path <- file.path(DIR_CACHE_API, paste0("nc_", level, "_", year, ".rds"))
  if (!file.exists(path)) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    b <- if (level == "county") tigris::counties(state = "NC", cb = TRUE, year = year)
         else tigris::tracts(state = "NC", cb = TRUE, year = year)
    saveRDS(b, path)
  }
  readRDS(path)
}

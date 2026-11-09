# 15_build_research_testset.R: sample 10 NIH awards (2 per topic) from the public NIH RePORTER API for the
# researcher-tab test set -> data/research_testset/reporter_sample.json.
# Outside service: POST https://api.reporter.nih.gov/v2/projects/search, no key, ONE request per topic (5 total),
# 1 second pause between requests. Raw responses are cached under data/cache/api/reporter/ by cached_fetch, so a rerun
# does not call the API again. Public data only. Run from the repo root: Rscript R/15_build_research_testset.R

here::i_am("R/15_build_research_testset.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_io.R"))

set.seed(20261109)
URL <- "https://api.reporter.nih.gov/v2/projects/search"
DIR_REPORTER <- here::here("data", "cache", "api", "reporter")
topics <- c("stroke imaging", "radiology AI", "MRI physics", "oncology imaging", "general biomedicine")
search_text <- c("stroke imaging", "radiology artificial intelligence", "magnetic resonance imaging physics",
                 "oncology imaging", "biomedical research")
ic_map <- readr::read_csv(here::here("data", "manual", "nih_ic_codes.csv"), show_col_types = FALSE)
MIN_ABSTRACT <- 600

fetch_topic <- function(i) {
  body <- list(
    criteria = list(fiscal_years = c(2024L, 2025L), advanced_text_search = list(
      operator = "and", search_field = "projecttitle,abstracttext", search_text = search_text[i])),
    include_fields = c("ProjectNum", "ProjectTitle", "AbstractText", "AgencyIcAdmin", "ActivityCode"),
    offset = 0L, limit = 50L)
  cached_fetch(URL, body = body, dir = DIR_REPORTER, key = paste0("reporter_", gsub(" ", "_", topics[i])), parse = "json")
}

pick <- function(x, ...) { for (n in c(...)) if (!is.null(x[[n]])) return(x[[n]]); NULL }

out <- list()
for (i in seq_along(topics)) {
  if (i > 1) Sys.sleep(1)
  res <- fetch_topic(i)$results
  stopifnot(is.data.frame(res), nrow(res) > 0)
  num <- as.character(pick(res, "project_num", "ProjectNum"))
  abbr <- pick(res, "agency_ic_admin", "AgencyIcAdmin")
  abbr <- if (is.data.frame(abbr)) as.character(abbr$abbreviation) else rep(NA_character_, nrow(res))
  act <- pick(res, "activity_code", "ActivityCode")
  act <- if (is.null(act)) rep(NA_character_, nrow(res)) else as.character(act)
  # fallback: activity code from the project number, e.g. 5R01NS123456-03 -> R01
  act <- ifelse(is.na(act) | act == "", sub("^[0-9]?([A-Z][0-9A-Z]{2})[A-Z]{2}.*$", "\\1", num), act)
  df <- tibble::tibble(project_num = num, ic_abbr = abbr, mechanism = act,
                       title = as.character(pick(res, "project_title", "ProjectTitle")),
                       abstract = trimws(as.character(pick(res, "abstract_text", "AbstractText"))))
  df$ic <- ic_map$ic[match(df$ic_abbr, ic_map$name)]
  df <- df[!is.na(df$ic) & !is.na(df$mechanism) & nzchar(df$mechanism) & !is.na(df$abstract) & nzchar(df$abstract) &
             !duplicated(df$project_num), ]
  long <- df[nchar(df$abstract) > MIN_ABSTRACT, ]
  if (nrow(long) >= 2) df <- long
  cat(sprintf("%s: %d usable of %d returned\n", topics[i], nrow(df), nrow(res)))
  take <- df[sample.int(nrow(df), min(2L, nrow(df))), ]
  for (k in seq_len(nrow(take))) out[[length(out) + 1]] <- list(
    id = paste0("reporter_", take$project_num[k]), source = "reporter", project_num = take$project_num[k],
    ic = take$ic[k], mechanism = take$mechanism[k], title = take$title[k], abstract = take$abstract[k], topic = topics[i])
}
dir.create(here::here("data", "research_testset"), showWarnings = FALSE, recursive = TRUE)
jsonlite::write_json(out, here::here("data", "research_testset", "reporter_sample.json"), auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("wrote %d awards\n", length(out)))

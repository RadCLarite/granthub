# agreement.R: runs the browser ranking math (tool/ranker.js) through V8 and compares it
# with the R ranking, at the default weights and at changed weights/filters. Sourced by
# run_tests.R and by build_tool.R. Needs data/processed/payload.json (R/10_run_ranking.R).

suppressPackageStartupMessages({ library(jsonlite); library(readr) })
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "score.R"))

check_r_js_agreement <- function() {
  items <- read_any(ITEMS_FILE)
  cr <- read_csv(CRITERIA_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
  cr$weight <- if ("weight" %in% names(cr)) suppressWarnings(as.numeric(cr$weight)) else NA_real_
  ctx <- V8::v8()
  ctx$eval(paste(readLines(here::here("src", "tool", "ranker.js"), warn = FALSE), collapse = "\n"))
  ctx$eval(paste0("var P = ", paste(readLines(PAYLOAD_JSON, warn = FALSE), collapse = "\n"), ";"))

  scores <- cr$id[cr$type == "score"]; filters <- cr$id[cr$type == "filter"]
  scenarios <- list(default = list(weights = NULL, filters_on = NULL))
  if (length(scores)) scenarios$reweighted <- list(weights = setNames(rep(c(0, 3), length.out = length(scores)), scores), filters_on = NULL)
  if (length(filters)) scenarios$filter_off <- list(weights = NULL, filters_on = setNames(rep(FALSE, length(filters)), filters))

  out <- list()
  for (nm in names(scenarios)) {
    s <- scenarios[[nm]]
    rk <- rank_items(items, cr, REF_DATE, ID_COL, NAME_COL, weights = s$weights, filters_on = s$filters_on)
    state <- toJSON(list(weights = if (is.null(s$weights)) NULL else as.list(s$weights),
                         filters_on = if (is.null(s$filters_on)) NULL else as.list(s$filters_on)),
                    auto_unbox = TRUE, null = "null")
    js <- fromJSON(ctx$eval(paste0(
      "JSON.stringify(Ranker.run(P, ", state, ").ranked.map(function (r) { return { id: r.id, total: r.total, why: r.why }; }))")))
    same_ids <- identical(as.character(js$id), rk$ranked$id)
    same_tot <- same_ids && isTRUE(all.equal(as.numeric(js$total), rk$ranked$total, tolerance = 1e-4))
    same_why <- same_ids && identical(as.character(js$why), rk$ranked$why)
    out[[nm]] <- tibble::tibble(
      name = paste0("R and JS agree (", nm, "): order, totals, explanations"),
      ok = same_ids && same_tot && same_why,
      got = paste0("order ", same_ids, ", totals ", same_tot, ", why ", same_why))
  }
  dplyr::bind_rows(out)
}

# run_tests.R: unit tests, integration test, your own test cases, R/JS agreement, and
# the LLM label guard. Prints "N of N tests pass" and writes outs/test_report.csv.
# Test cases are written BEFORE looking at results (Deloitte: set the rule first).
# Run from the repo root: Rscript tests/run_tests.R

here::i_am("tests/run_tests.R")
# Tests read the frozen snapshot: pin the scoring clock (AS_OF_DATE, 00_config.R) to the snapshot date, not today.
# Keep in step with SNAPSHOT_AS_OF_DATE in 00_config.R (checked below).
Sys.setenv(AS_OF_DATE = "2026-11-07")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_io.R"))
source(here::here("R", "helpers_llm.R"))
source(here::here("R", "score.R"))
source(here::here("R", "helpers_rank.R"))
source(here::here("tests", "agreement.R"))
stopifnot(identical(AS_OF_DATE, SNAPSHOT_AS_OF_DATE))
suppressPackageStartupMessages({ library(readr); library(tibble); library(dplyr) })

results <- list()
check <- function(section, name, ok, got = "") {
  results[[length(results) + 1]] <<- tibble(section = section, name = name, ok = isTRUE(ok), got = as.character(got))
}
fails <- function(expr) inherits(try(expr, silent = TRUE), "try-error")
ref <- as.Date("2026-11-06")

# ---- 0. Unit: who a grant reaches (tag_groups, display only) --------------------------
g <- "unit: reach tags"
tg <- tag_groups(c("Supportive Services for Veteran Families", "Clean diesel buses", "Bridge repair"),
                 c("Serves older adults too.", "Researchers with disabilities and senior/key personnel; protect American children.", "Replaces aging infrastructure."))
check(g, "title match first, quote is the title", identical(tg[[1]]$id, c("veterans", "older_adults")) && tg[[1]]$quote[1] == "Supportive Services for Veteran Families")
check(g, "boilerplate ignored (no disability, senior or children tag)", nrow(tg[[2]]) == 0)
check(g, "aging infrastructure is not older adults", nrow(tg[[3]]) == 0)

# ---- 1. Unit: every rule on known input ---------------------------------------------
u <- "unit: rules"
check(u, "eq", identical(rule_eval(c("a", "b", NA), "eq", "a", ref), c(TRUE, FALSE, NA)))
check(u, "in", identical(rule_eval(c("a", "c"), "in", "a|b", ref), c(TRUE, FALSE)))
check(u, "gte", identical(rule_eval(c(1, 5, NA), "gte", "5", ref), c(FALSE, TRUE, NA)))
check(u, "between", identical(rule_eval(c(1, 5, 9), "between", "2|8", ref), c(FALSE, TRUE, FALSE)))
check(u, "contains is case-insensitive", identical(rule_eval(c("Rural clinic", "urban"), "contains", "rural|farm", ref), c(TRUE, FALSE)))
check(u, "is_true", identical(rule_eval(c("TRUE", "no", "yes"), "is_true", "", ref), c(TRUE, FALSE, TRUE)))
check(u, "not_na treats empty as missing", identical(rule_eval(c("x", "", NA), "not_na", "", ref), c(TRUE, FALSE, FALSE)))
check(u, "date_gte_days", identical(rule_eval(c("2026-12-06", "2026-11-20"), "date_gte_days", "30", ref), c(TRUE, FALSE)))
check(u, "scale clamps to 0..1", isTRUE(all.equal(rule_eval(c(0, 50, 200), "scale", "0|100", ref), c(0, 0.5, 1))))
check(u, "scale can run downhill (smaller is better)", isTRUE(all.equal(rule_eval(c(0, 100), "scale", "100|0", ref), c(1, 0))))
check(u, "unknown rule errors", fails(rule_eval(1, "nope", "", ref)))

# ---- 2. Unit: bad criteria are rejected with a clear error --------------------------
toy <- tibble(id = c("a", "b"), name = c("A", "B"), x = c(1, 2))
base_cr <- tibble(id = "s", type = "score", label = "S", field = "x", rule = "scale", value = "0|2", weight = 1)
check("unit: criteria", "missing field is rejected", fails(rank_items(toy, mutate(base_cr, field = "zzz"), ref)))
check("unit: criteria", "duplicate ids are rejected", fails(rank_items(toy, bind_rows(base_cr, base_cr), ref)))
check("unit: criteria", "scale not allowed on a filter", fails(rank_items(toy, mutate(base_cr, type = "filter"), ref)))

# ---- 2b. Unit: score.R defects from the Nov 6 triage ---------------------------------
d2 <- tibble(id = c("a", "b", "c"), name = c("A", "B", "C"), x = c(1, NA, 2), y = c(NA, NA, 1))
two <- bind_rows(base_cr, mutate(base_cr, id = "s2", field = "y", value = "0|1"))
rk2 <- rank_items(d2, two, ref, "id", "name")
check("unit: score", "missing part is dropped and weights rescale", isTRUE(all.equal(rk2$all$total[rk2$all$id == "a"], 50)))
check("unit: score", "item with every part missing gets NA total and ranks last", is.na(rk2$all$total[rk2$all$id == "b"]) && tail(rk2$ranked$id, 1) == "b")
check("unit: score", "all weights zero is an error", fails(rank_items(d2, mutate(two, weight = 0), ref, "id", "name")))
fo <- tibble(id = "f", type = "filter", label = "F", field = "x", rule = "gte", value = "2", weight = NA_real_)
check("unit: score", "filter-only table does not crash", !fails(rank_items(d2, fo, ref, "id", "name")))
check("unit: score", "duplicate item ids are rejected", fails(rank_items(bind_rows(d2, d2[1, ]), base_cr, ref, "id", "name")))
check("unit: score", "contains is plain text, not a regex", identical(rule_eval(c("a.b", "axb"), "contains", ".", ref), c(TRUE, FALSE)))
check("unit: score", "dropped_by holds filter ids", identical(rank_items(d2, fo, ref, "id", "name")$dropped$dropped_by[1], "f"))

check("display text", "entities, zero-width and ligatures are cleaned", identical(clean_text(c("A &#8211; B", "x&#8203;y&#65279;", "\ufb01nancial", NA)), c("A \u2013 B", "xy", "financial", NA)))
check("eligibility", "tribal title on an ask item is hidden, state+tribal titles are not", identical(tribal_title_rule(tibble(eligibility = c("ask","ask","yes","ask"), elig_source = "code", elig_quote = NA_character_), c("Tribal Colleges and Universities Program (TCUP)","Grants for States and Tribes","Tribal Self-Governance","Clean air grants"))$eligibility, c("no","ask","yes","ask")))
check("geography", "overseas post funder is flagged", identical(overseas_post(c("U.S. Mission to Italy","U.S. Embassy Praia","Bureau of Educational and Cultural Affairs","Environmental Protection Agency",NA)), c(TRUE,TRUE,FALSE,FALSE,FALSE)))
check("geography", "out-of-region names are flagged, NC-serving ones are not", identical(geo_other(c("RESTORE Act Direct Component","Partner with the Hawai&#699;i-Pacific Islands CESU","Atlanta EDA Planning","HIV Care Part B States/Territories (Pacific Islands)","Southeast region schools")), c(TRUE,TRUE,FALSE,FALSE,FALSE)))
check("geography", "other state in title is flagged", identical(geo_other(c("Grant for California schools","Great Lakes Unit","Texas and North Carolina pilot","Clean air grants",NA)), c(TRUE,TRUE,FALSE,FALSE,FALSE)))

check("program map", "mapped listing lifts fit to the floor and notes why", {
  m <- apply_program_map(tibble::tibble(agency_id = c("deq", "deq", "dpi"), fit = c(0.1, 0.95, 0.1)),
                         c("66.039", "66.039", "10.001"), data.frame(agency_id = "deq", cfda = "66.039", why = "w"))
  identical(m$fit, c(MAP_FIT_FLOOR, 0.95, 0.1)) && identical(m$map_note, c("w", "w", NA_character_))
})

# ---- 3. Integration: whole pipeline on the project data -----------------------------
i <- "integration"
items <- read_any(ITEMS_FILE)
cr <- read_csv(CRITERIA_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
cr$weight <- if ("weight" %in% names(cr)) suppressWarnings(as.numeric(cr$weight)) else NA_real_
rk <- rank_items(items, cr, REF_DATE, ID_COL, NAME_COL)
check(i, "every item is ranked or dropped exactly once", nrow(rk$ranked) + nrow(rk$dropped) == nrow(items),
      paste(nrow(rk$ranked), "+", nrow(rk$dropped), "of", nrow(items)))
check(i, "ids are unique", !anyDuplicated(items[[ID_COL]]))
check(i, "totals are between 0 and 100", all(rk$ranked$total >= 0 & rk$ranked$total <= 100, na.rm = TRUE))
check(i, "ranking is sorted by total", !is.unsorted(rev(rk$ranked$total)))
check(i, "rerun gives the same ranking (reproducible)", identical(rk$ranked$id, rank_items(items, cr, REF_DATE, ID_COL, NAME_COL)$ranked$id))
sc <- cr$id[cr$type == "score"]
if (length(sc)) {
  check(i, "all weights zero stops with an error", fails(rank_items(items, cr, REF_DATE, ID_COL, NAME_COL, weights = setNames(rep(0, length(sc)), sc))))
}
filt <- cr$id[cr$type == "filter"]
if (length(filt)) {
  off <- rank_items(items, cr, REF_DATE, ID_COL, NAME_COL, filters_on = setNames(rep(FALSE, length(filt)), filt))
  check(i, "turning every filter off keeps every item", nrow(off$ranked) == nrow(items))
}

# ---- 4. Your test cases (data/manual/test_cases.csv) -------------------------------
tc_path <- TEST_CASES_FILE
tc <- read_csv(tc_path, show_col_types = FALSE, col_types = cols(.default = col_character()))
ranked <- rk$ranked
for (r in seq_len(nrow(tc))) {
  t <- tc[r, ]
  ok <- switch(t$type,
    in_top_n       = t$item_id %in% head(ranked$id, as.integer(t$n)),
    ranks_above    = t$item_id %in% ranked$id && t$other_id %in% ranked$id &&
                       match(t$item_id, ranked$id) < match(t$other_id, ranked$id),
    not_in_ranking = !(t$item_id %in% ranked$id),
    dropped_by     = grepl(t$filter_id, rk$dropped$dropped_by[rk$dropped$id == t$item_id], fixed = TRUE),
    points_equal   = isTRUE(all.equal(rk$all[[paste0("pts_", t$criterion_id)]][match(t$item_id, rk$all$id)], as.numeric(t$expected))),
    FALSE)
  check("your test cases", paste0(t$case_id, ": ", t$description), ok)
}

# ---- 5. R and JS agree -------------------------------------------------------------
if (!file.exists(PAYLOAD_JSON)) {
  check("R and JS agree", "payload.json exists (run R/10_run_ranking.R)", FALSE)
} else if (!is.null(jsonlite::fromJSON(PAYLOAD_JSON)$rows)) {
  # Contract-shape payload (docs/contract.md): the shipped tool shows R's rank and fit_score as written and
  # only re-sorts by fit_score x weight in the browser (tool/matchmaker.html). tool/ranker.js is for the toy shape.
  # So the agreement check is: the payload order is exactly the order of fit_score (ties by opp_id) within each agency.
  pl0 <- jsonlite::fromJSON(PAYLOAD_JSON)$rows; top0 <- pl0[pl0$in_top10, ]
  ok_order <- all(vapply(split(top0, top0$agency_id), function(d) {
    o <- order(-d$fit_score, d$opp_id, method = "radix"); identical(d$opp_id[o], d$opp_id[order(d$rank)]) }, logical(1)))
  check("R and JS agree", "payload rank order equals fit_score order inside every agency", ok_order)
  rk0 <- readr::read_csv(RANKING_CSV, show_col_types = FALSE)
  chk_rank <- merge(top0[, c("agency_id","opp_id","rank")], transform(rk0, opp_id = sub("^[^:]*:", "", id))[, c("agency_id","opp_id","rank")],
                    by = c("agency_id","opp_id"), suffixes = c("_payload","_full"))
  check("R and JS agree", "payload ranks never beat the full ranking order (same relative order)", all(vapply(split(chk_rank, chk_rank$agency_id),
    function(d) !is.unsorted(d$rank_full[order(d$rank_payload)]), logical(1))))
} else {
  ag <- check_r_js_agreement()
  for (k in seq_len(nrow(ag))) check("R and JS agree", ag$name[k], ag$ok[k], ag$got[k])
}

# ---- 5b. payload.json and rankings_backtest.csv follow docs/contract.md ----------
if (file.exists(PAYLOAD_JSON) && file.exists(BACKTEST_CSV)) {
  pl <- jsonlite::fromJSON(PAYLOAD_JSON); pr <- pl$rows
  want <- c("agency_id","opp_id","opp_number","title","status","close_date","days_left","date_note","fit_score","rank",
            "in_top10","eligibility","elig_source","elig_quote","reader_label","reader_quote","goal_id","goal_snippet",
            "opp_snippet","cfda_list","award_ceiling","signature_tier","tier_source","nc_won_before","url")
  check("payload contract", "top level keys", all(c("data_as_of","window_days","agencies","rows") %in% names(pl)))
  check("payload contract", "every contract row field present", all(want %in% names(pr)))
  check("payload contract", "32 agencies", nrow(pl$agencies) == 32)
  check("payload contract", "at most 10 Top 10 rows per agency", max(table(pr$agency_id[pr$in_top10])) <= 10)
  check("payload contract", "Top 10 holds open items only (no forecasts)", !any(pr$status[pr$in_top10] == "forecasted"))
  check("payload contract", "Top 10 rows are never hidden as ineligible", !any(pr$eligibility[pr$in_top10] == "no"))
  check("payload contract", "eligibility is yes, no or ask", all(pr$eligibility %in% c("yes","no","ask")))
  check("payload contract", "fit_score within 0 to 1", all(pr$fit_score >= 0 & pr$fit_score <= 1, na.rm = TRUE))
  check("payload contract", "unknown ceiling is null, never 0", !any(pr$award_ceiling == 0, na.rm = TRUE))
  check("payload contract", "tier is writer, supervisor, leadership or unknown", all(pr$signature_tier %in% c("writer","supervisor","leadership","unknown")))
  chk <- signature_tier(c("Yes","Yes","No",NA), c(2e6, 5e5, 9e9, 9e9))$signature_tier
  check("payload contract", "tier rules: big match leadership, small match supervisor, no match writer, missing unknown", identical(chk, c("leadership","supervisor","writer","unknown")))
  check("payload contract", "a tier is never set without a stated cost share", all(pr$signature_tier[is.na(pr$tier_source)] == "unknown"))
  check("payload contract", "no stub flag", is.null(pl$stub))
  bt <- readr::read_csv(BACKTEST_CSV, show_col_types = FALSE)
  check("backtest contract", "columns", identical(names(bt), c("agency_id","window_start","window_end","window_weeks","opp_id",
        "opp_number","cfda_list","close_date","fit_score","rank")))
  check("backtest contract", "at most 50 per agency and window", max(table(bt$agency_id, bt$window_start, bt$window_weeks)) <= 50)
  check("backtest contract", "every item closes on or after window start", all(bt$close_date >= bt$window_start))
}

# ---- 5c. Rerun check: same input gives an identical payload.json ----------------------
if (file.exists(PAYLOAD_JSON) && file.exists(file.path(DIR_PROCESSED, "items.csv")) && file.exists(RANKING_CSV)) {
  before <- unname(tools::md5sum(PAYLOAD_JSON))
  status <- system2("Rscript", here::here("R", "11_build_payload.R"), stdout = FALSE, stderr = FALSE)
  check("rerun", "11_build_payload.R runs", status == 0)
  check("rerun", "payload.json identical after rerun", identical(before, unname(tools::md5sum(PAYLOAD_JSON))))
}

# ---- 6. LLM guard: labels need a verifiable quote; cache; shards -------------------
l <- "llm guard"
DIR_CACHE_LLM <- tempfile("llm_cache_"); LLM_MODEL <- "test-model"
text <- "The program funds clinics in rural counties with few doctors."
levs <- c("yes", "no")
good <- llm_label(text, "Does it serve rural areas?", levs, .chat_fn = function(p) '{"label":"yes","evidence":"clinics in rural counties"}')
check(l, "label with a real quote is kept", good$label == "yes" && good$evidence_ok)
bad <- llm_label("A different text about roads.", "Does it serve rural areas?", levs, .chat_fn = function(p) '{"label":"yes","evidence":"funds rural clinics"}')
check(l, "label with a made-up quote falls back to the none level", bad$label == "no" && !bad$evidence_ok)
junk <- llm_label("Roads text.", "Rural?", levs, .chat_fn = function(p) "not json")
check(l, "unparseable model output falls back to the none level", junk$label == "no")
again <- llm_label(text, "Does it serve rural areas?", levs, .chat_fn = function(p) stop("should not be called"))
check(l, "second call is served from the cache", again$cached && again$label == "yes")
df <- tibble(id = 1:7, txt = rep(text, 7))
parts <- lapply(1:3, function(k) label_items(df, "id", "txt", "Does it serve rural areas?", levs, shard = c(k, 3), .chat_fn = function(p) '{"label":"yes","evidence":"clinics in rural counties"}'))
ids_seen <- sort(unlist(lapply(parts, `[[`, "id")))
check(l, "shards cover every item exactly once", identical(ids_seen, 1:7))

# ---- 7. Ingest: merged opportunities table -----------------------------------------
source(here::here("tests", "test_ingest.R"))
source(here::here("tests", "test_plan_tables.R"))
source(here::here("tests", "test_research.R"))
source(here::here("tests", "test_foundations.R"))

# ---- Report ------------------------------------------------------------------------
rep <- bind_rows(results)
dir.create(DIR_OUTS, showWarnings = FALSE, recursive = TRUE)
write_csv(rep, file.path(DIR_OUTS, "test_report.csv"))
if (!all(rep$ok)) print(as.data.frame(rep[!rep$ok, c("section", "name", "got")]))
cat(sprintf("%d of %d tests pass%s\n", sum(rep$ok), nrow(rep), if (USING_EXAMPLE) " (on TOY example data)" else ""))
if (!all(rep$ok)) quit(status = 1)

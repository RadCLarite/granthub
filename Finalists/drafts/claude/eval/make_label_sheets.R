# make_label_sheets.R  -- draws the 20-item test pool per agency and writes blind label sheets.
# Run:  Rscript make_label_sheets.R
#
# Decision 12: three agencies, 20 items each, two labelers per item. The pool is drawn
# HERE, from the keyword baseline and a seeded random draw, BEFORE any ranking exists.
# It does not use the ranker at all (no ranking input, on purpose), so the pool cannot
# be tuned to the ranker. Rerunning gives identical sheets (fixed seed).
# Nothing here fills a label. Sheets show no rank, score, stratum or keyword hits;
# the source stratum lives only in sheets/key_hidden_DO_NOT_SHARE.csv.

suppressMessages(library(data.table))

# ---- parameters (names must match agency_goal_summaries.csv exactly) --------
DEMO_AGENCIES <- c("Department of Public Schools",
                   "Department of Environmental Quality",
                   "Department of Health and Human Services")   # decision 12
N_BASELINE_TOP <- 6    # top keyword-baseline hits
N_BASELINE_MID <- 6    # mid-rank keyword hits
N_RANDOM       <- 8    # random from everything else (kept on purpose, see pool_rules.md)
SEED           <- 2026
LABELERS       <- c("A", "B")
SUMMARY_CHARS  <- 500
FAR_FUTURE     <- as.IDate("2029-12-31")   # decision 8: close dates in 2030 or later (70 posted items) read "rolling or no date listed"

args_all <- commandArgs(FALSE)
here <- dirname(normalizePath(sub("^--file=", "", args_all[grep("^--file=", args_all)][1])))
repo <- normalizePath(file.path(here, "..", "..", ".."))
opps  <- fread(file.path(repo, "data", "processed", "opportunities.csv"), colClasses = list(character = c("opp_id", "opp_number")))
goals <- fread(file.path(repo, "src", "docs", "agency_goal_summaries.csv"))
out_dir <- file.path(here, "sheets")
source(file.path(here, "keyword_baseline.R"))

clean_text <- function(x) {
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&#8217;|&#39;|&rsquo;", "'", x)
  x <- gsub("&#8211;|&ndash;", "-", x)
  x <- gsub("&quot;|&#8220;|&#8221;", "\"", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  trimws(gsub("\\s+", " ", x))
}
or_unknown <- function(x) { x <- as.character(x); ifelse(is.na(x) | !nzchar(trimws(x)), "unknown", x) }
spaced <- function(lo, hi, n) {
  if (hi < lo) return(integer(0))
  unique(round(seq(lo, hi, length.out = min(n, hi - lo + 1))))
}

key_rows <- list()
for (ag in DEMO_AGENCIES) {
  if (!ag %in% goals$agency) stop("Agency label not found in goals file: '", ag, "'. Labels include: ",
                                  paste(head(unique(goals$agency), 40), collapse = " | "))
  ai <- match(ag, DEMO_AGENCIES)
  terms <- agency_terms(ag, goals)
  message(ag, ": ", length(terms), " keyword terms")
  pool <- opps[status %in% POOL_STATUSES]
  pool <- merge(pool, keyword_baseline(pool, terms), by = "opp_id"); setorder(pool, kw_rank)
  picked <- list(); add <- function(ids, lab) for (i in ids) picked[[i]] <<- c(picked[[i]], lab)

  hits <- pool[kw_score > 0]
  if (nrow(hits) < N_BASELINE_TOP + N_BASELINE_MID) warning(ag, ": few keyword hits; baseline strata short.")
  top_ids <- head(hits$opp_id, N_BASELINE_TOP); add(top_ids, "baseline_top")
  rem <- hits[!opp_id %in% top_ids]       # mid band: middle third of remaining hits, evenly spaced
  if (nrow(rem) > 0) add(rem$opp_id[spaced(max(ceiling(nrow(rem)/3), 1), max(floor(2*nrow(rem)/3), 1), N_BASELINE_MID)], "baseline_mid")
  set.seed(SEED + ai)
  rest <- sort(setdiff(pool$opp_id, names(picked)))
  add(sample(rest, min(N_RANDOM, length(rest))), "random_rest")

  sel <- pool[opp_id %in% names(picked)]
  set.seed(SEED + 100 + ai); sel <- sel[sample.int(nrow(sel))]
  sel[, item_no := seq_len(.N)]
  sel[, strata := vapply(opp_id, function(i) paste(unique(picked[[i]]), collapse = ";"), "")]

  # Display rules from decisions 8 and 9
  is_notice <- sel$status == "notice"
  close_txt <- ifelse(is_notice, "no deadline (notice)",
               ifelse(is.na(sel$close_date), "no date listed",
               ifelse(sel$close_date > FAR_FUTURE, "rolling or no date listed", format(sel$close_date))))
  award_txt <- ifelse(is_notice, "none (notice)",
               ifelse(is.na(sel$award_ceiling), "unknown",
               ifelse(sel$award_ceiling == 0, "unknown (listed as 0)",
                      format(as.numeric(sel$award_ceiling), scientific = FALSE, big.mark = ","))))
  base <- data.table(item_no = sel$item_no, opp_number = sel$opp_number, title = clean_text(sel$title),
    agency_funder = clean_text(or_unknown(sel$agency)), status = sel$status, close_date = close_txt,
    award_ceiling = award_txt, summary_short = substr(clean_text(or_unknown(sel$summary)), 1, SUMMARY_CHARS),
    url = or_unknown(sel$url))

  slug <- gsub("^_|_$", "", gsub("[^a-z]+", "_", tolower(ag)))
  for (lb in LABELERS) {
    sh <- copy(base)
    if (lb != LABELERS[1]) { set.seed(SEED + 200 + match(lb, LABELERS) + ai); sh <- sh[sample.int(nrow(sh))] }
    sh[, `:=`(labeler = lb, label = "", note = "")]   # label: relevant / maybe / not relevant
    fwrite(sh, file.path(out_dir, sprintf("labels_%s_labeler%s.csv", slug, lb)))
    message("  wrote labeler ", lb, " sheet (", nrow(sh), " rows)")
  }
  key_rows[[ag]] <- data.table(agency = ag, item_no = sel$item_no, opp_id = sel$opp_id, opp_number = sel$opp_number,
    source_stratum = sel$strata, kw_rank = sel$kw_rank, kw_score = sel$kw_score, kw_hits = sel$kw_hits)
  print(table(sel$status)); print(table(unlist(strsplit(sel$strata, ";"))))
}
fwrite(rbindlist(key_rows), file.path(out_dir, "key_hidden_DO_NOT_SHARE.csv"))
message("wrote key file. Labelers must never open it.")

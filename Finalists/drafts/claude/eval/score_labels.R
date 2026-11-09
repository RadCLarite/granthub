# score_labels.R  -- scores team-labelled sheets against the ranker and the keyword baseline.
#
# Usage (from this folder):
#   Rscript score_labels.R sheets=sheets key=sheets/key_hidden_DO_NOT_SHARE.csv \
#           ranking=path/to/ranking.csv out=results
# ranking (optional): columns agency, opp_id, rank (1 = best), optional score. It must be the
# agency's FULL ranked list of opportunities, not just the 20 pool items (see N below).
# Without it, only the keyword baseline is scored.
#
# Labels are "team-labelled", never ground truth. Numbers come from a 20-item pool per agency.

suppressMessages(library(data.table))

# ---- settings ---------------------------------------------------------------
# Decision 12 (planning/08_product_decisions.md): 70% recall pass bar. Kent can change it.
PASS_RECALL_AT_N <- 0.70
# N = the shortlist cap, counted in the agency's FULL ranked list (decision 3; the cap lives in
# src/R/00_config.R). It is NOT the pool size. Kent must set it. NA = no primary number is computed.
N_SHORTLIST <- NA_integer_
# Secondary only:
TOP_K_PRECISION <- 10L
PASS_KAPPA_MIN  <- NA_real_      # Kent sets before scoring, or it stays unjudged
RECALL_CURVE_N  <- c(10L, 25L, 50L, 100L, 200L)   # for "recall versus shortlist length" (decision 11)
MIN_UNIVERSE_MULT <- 5           # ranked list must be at least this many times the pool size

LABEL_LEVELS <- c("relevant", "maybe", "not relevant")
# Two readings of what counts as a hit. Kent must say which one is THE number.
READINGS <- list("relevant only" = "relevant", "relevant plus maybe" = c("relevant", "maybe"))

# ---------------- pure functions (tested in test_metrics.R) ----------------
order_ids <- function(ids, rank) { ids <- as.character(ids); ids[order(rank, ids)] }   # ties broken by id

# Guard for the N trap. If ranks are computed inside the 20-item pool and N >= 20, recall is
# automatically 100% and means nothing. Refuse when the ranked list is not clearly larger than
# the pool; warn when N is as big as the pool. Returns "ok" or "warn"; stops otherwise.
check_n_valid <- function(N, n_universe, n_pool, mult = MIN_UNIVERSE_MULT) {
  if (is.na(N)) stop("N is not set. Kent sets N (the shortlist cap on the FULL ranked list) before scoring.")
  if (n_universe < mult * n_pool)
    stop("Ranked list has only ", n_universe, " items for a pool of ", n_pool,
         ". Recall needs the agency's FULL ranked list, not the pool; inside the pool recall at N >= pool size is trivially 100%. Refusing.")
  if (N >= n_universe) stop("N (", N, ") is not smaller than the ranked list (", n_universe, "); every item would count as shortlisted.")
  if (N >= n_pool) { warning("N (", N, ") is >= the pool size (", n_pool, "). Fine only if N is the shortlist cap on the full list, not the pool size. Confirm with Kent."); return("warn") }
  "ok"
}

# Recall at N: of pool items whose verdict is TRUE (positive), the share that sit in the top N.
# verdict: named logical (name = id; NA = unusable/blank). ranked_ids best first.
recall_at_n <- function(ranked_ids, verdict, N) {
  pos <- names(verdict)[!is.na(verdict) & verdict]
  found <- sum(pos %in% head(ranked_ids, N))
  list(value = if (length(pos) == 0) NA_real_ else found / length(pos), n_found = found, n_positive = length(pos))
}

# Precision at k on labeled items only (secondary).
precision_at_k <- function(ranked_ids, verdict, k = 10L) {
  top <- head(ranked_ids, k); v <- unname(verdict[top]); n_lab <- sum(!is.na(v))
  list(value = if (n_lab == 0) NA_real_ else sum(v, na.rm = TRUE) / n_lab, n_relevant = sum(v, na.rm = TRUE),
       n_labeled = n_lab, n_unlabeled = length(top) - n_lab, n_in_top = length(top))
}

# Decision 3 helper: the score threshold that keeps `target` recall inside the top N.
# scores: named numeric (name = id) for the agency's full list. Take the top N by score; among
# pool-positive items in it, find the k-th highest score, k = ceiling(target * all pool positives).
# Items with score >= that threshold are flagged. It is the tightest threshold that still keeps the target,
# i.e. the lowest score among the positives you must keep. NA if the top N holds fewer than k positives.
threshold_for_recall <- function(scores, verdict, N, target = 0.70) {
  pos <- names(verdict)[!is.na(verdict) & verdict]
  if (length(pos) == 0) return(list(threshold = NA_real_, k = NA_integer_, n_positive = 0L, reachable = FALSE))
  k <- ceiling(target * length(pos) - 1e-9)
  ord <- order(-scores, names(scores)); topN <- names(scores)[ord][seq_len(min(N, length(scores)))]
  ps <- sort(scores[intersect(pos, topN)], decreasing = TRUE)
  if (length(ps) < k) return(list(threshold = NA_real_, k = k, n_positive = length(pos), reachable = FALSE))
  list(threshold = unname(ps[k]), k = k, n_positive = length(pos), reachable = TRUE)
}

agreement <- function(a, b) {
  ok <- !is.na(a) & !is.na(b); a <- a[ok]; b <- b[ok]; n <- length(a)
  if (n == 0) return(list(n = 0L, pct = NA_real_, kappa = NA_real_))
  po <- mean(a == b); lv <- union(a, b)
  pe <- sum(vapply(lv, function(l) mean(a == l) * mean(b == l), numeric(1)))
  list(n = n, pct = po, kappa = if (isTRUE(all.equal(pe, 1))) NA_real_ else (po - pe) / (1 - pe))
}

# Turn two labelers' labels into TRUE/FALSE/NA under a reading (which labels count) and a rule
# (strict = both count; lenient = either counts). Blank by either labeler stays NA (never guessed).
combine_verdict <- function(a, b, positive = "relevant", rule = c("strict", "lenient")) {
  rule <- match.arg(rule); pa <- a %in% positive; pb <- b %in% positive
  out <- if (rule == "strict") pa & pb else pa | pb
  out[is.na(a) | is.na(b)] <- NA; out
}

norm_label <- function(x) { x <- tolower(trimws(as.character(x))); x[is.na(x) | x == ""] <- NA; x }
pass_text <- function(value, mark) {
  if (is.na(mark)) return("no pass mark set"); if (is.na(value)) return("cannot tell (no value)")
  if (value >= mark) "PASS" else "FAIL"
}

# ---------------- main (only when run as a script) ----------------
score_main <- function(argv) {
  kv <- strsplit(argv, "=", fixed = TRUE)
  opt <- setNames(lapply(kv, function(z) paste(z[-1], collapse = "=")), vapply(kv, `[`, "", 1))
  sheets_dir <- if (!is.null(opt$sheets)) opt$sheets else "sheets"
  key_path <- if (!is.null(opt$key)) opt$key else file.path(sheets_dir, "key_hidden_DO_NOT_SHARE.csv")
  rank_path <- opt$ranking; out_dir <- if (!is.null(opt$out)) opt$out else "results"
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  message("\n*** Kent must say which reading counts as THE recall number: 'relevant only' or 'relevant plus maybe', ",
          "and whether a pool item needs both labelers (strict) or either (lenient). All four are shown. ***")
  if (is.na(N_SHORTLIST)) message("*** Kent sets N (the shortlist cap on the full ranked list) before scoring. N is NA, so only the recall-by-N curve is shown, no pass/fail. ***")
  if (is.na(PASS_KAPPA_MIN)) message("*** No kappa pass mark set; agreement is shown without judgment. ***")

  key <- fread(key_path, colClasses = list(character = c("opp_id", "opp_number")))
  files <- list.files(sheets_dir, pattern = "^labels_.*_labeler[A-Z]\\.csv$", full.names = TRUE)
  if (length(files) == 0) stop("No label sheets found in ", sheets_dir)
  lab <- rbindlist(lapply(files, function(f) { d <- fread(f, colClasses = "character"); d[, file := basename(f)]; d }), fill = TRUE)
  lab[, label := norm_label(label)]
  badn <- sum(!is.na(lab$label) & !lab$label %in% LABEL_LEVELS)
  if (badn) { warning(badn, " labels are not exactly relevant / maybe / not relevant; treated as blank."); lab[!label %in% LABEL_LEVELS, label := NA_character_] }
  lab[, item_no := as.integer(item_no)]
  sl <- function(x) gsub("^_|_$", "", gsub("[^a-z]+", "_", tolower(x)))
  key[, slug := sl(agency)]; lab[, slug := sub("^labels_(.*)_labeler[A-Z]\\.csv$", "\\1", file)]
  lab <- merge(lab, key[, .(slug, item_no, agency, opp_id)], by = c("slug", "item_no"), all.x = TRUE)
  if (anyNA(lab$opp_id)) stop("Some sheet rows do not match the key. Wrong key file?")

  ranking <- NULL
  if (!is.null(rank_path) && nzchar(rank_path)) {
    ranking <- fread(rank_path, colClasses = list(character = c("agency", "opp_id")))
    if (!all(c("agency", "opp_id", "rank") %in% names(ranking))) stop("ranking needs agency, opp_id, rank")
  } else message("No ranking file: scoring the keyword baseline only.")

  here <- tryCatch(dirname(normalizePath(sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))][1]))), error = function(e) ".")
  source(file.path(here, "keyword_baseline.R"))
  repo <- if (!is.null(opt$repo)) opt$repo else normalizePath(file.path(here, "..", "..", ".."))
  opps <- fread(file.path(repo, "data", "processed", "opportunities.csv"), colClasses = list(character = c("opp_id", "opp_number")))
  goals <- fread(file.path(repo, "src", "docs", "agency_goal_summaries.csv"))

  summ <- list(); curve <- list(); detail <- list(); disag <- list(); thr <- list()
  for (ag in unique(lab$agency)) {
    L <- lab[agency == ag]; labelers <- sort(unique(L$labeler))
    if (length(labelers) != 2) { warning(ag, ": expected 2 labelers, found ", length(labelers)); next }
    wide <- dcast(L, opp_id ~ labeler, value.var = "label"); ca <- labelers[1]; cb <- labelers[2]
    n_pool <- nrow(wide)
    agr <- agreement(wide[[ca]], wide[[cb]])
    dd <- wide[!is.na(get(ca)) & !is.na(get(cb)) & get(ca) != get(cb)]
    if (nrow(dd)) disag[[ag]] <- data.table(agency = ag, opp_id = dd$opp_id, A = dd[[ca]], B = dd[[cb]])
    cat(sprintf("\n== %s (team-labelled, pool of %d) ==\nboth labelled: %d | agreement: %.1f%% | kappa (3 labels): %s | maybe labels: %d | blank labels: %d | disagreements: %d\n",
        ag, n_pool, agr$n, 100 * agr$pct, ifelse(is.na(agr$kappa), "NA", sprintf("%.3f", agr$kappa)),
        sum(wide[[ca]] == "maybe", na.rm = TRUE) + sum(wide[[cb]] == "maybe", na.rm = TRUE),
        sum(is.na(wide[[ca]])) + sum(is.na(wide[[cb]])), nrow(dd)))
    summ[[paste(ag, "agr")]] <- data.table(agency = ag, reading = "agreement", rule = "", method = "labelers",
      recall_at_N = NA_real_, n_positive = NA_integer_, precision_at_10 = agr$pct, labeled_in_top10 = agr$n,
      status = sprintf("percent agreement in precision_at_10 column; kappa=%s; %s", ifelse(is.na(agr$kappa), "NA", sprintf("%.3f", agr$kappa)), pass_text(agr$kappa, PASS_KAPPA_MIN)))

    pool <- opps[status %in% POOL_STATUSES]
    kb <- keyword_baseline(pool, agency_terms(ag, goals))
    methods <- list(keyword_baseline = list(ids = kb$opp_id, scores = setNames(kb$kw_score, kb$opp_id)))
    if (!is.null(ranking)) {
      r <- ranking[agency == ag]
      if (nrow(r) == 0) warning(ag, ": no rows for this agency in ranking file") else {
        sc <- if ("score" %in% names(r)) setNames(r$score, r$opp_id) else NULL
        methods <- c(list(ranker = list(ids = order_ids(r$opp_id, r$rank), scores = sc)), methods)
      }
    }
    for (m in names(methods)) {
      universe <- length(methods[[m]]$ids)
      ok <- !is.na(N_SHORTLIST)
      if (ok) check_n_valid(N_SHORTLIST, universe, n_pool)     # stops on the trivial-100% trap
    }
    for (rd in names(READINGS)) for (rule in c("strict", "lenient")) {
      v <- setNames(combine_verdict(wide[[ca]], wide[[cb]], READINGS[[rd]], rule), wide$opp_id)
      for (m in names(methods)) {
        ids <- methods[[m]]$ids
        rec <- if (is.na(N_SHORTLIST)) list(value = NA_real_, n_found = NA, n_positive = sum(v, na.rm = TRUE)) else recall_at_n(ids, v, N_SHORTLIST)
        p <- precision_at_k(ids, v, TOP_K_PRECISION)
        pos <- names(v)[!is.na(v) & v]
        summ[[paste(ag, rd, rule, m)]] <- data.table(agency = ag, reading = rd, rule = rule, method = m,
          recall_at_N = rec$value, n_positive = rec$n_positive, precision_at_10 = p$value, labeled_in_top10 = p$n_labeled,
          status = pass_text(rec$value, PASS_RECALL_AT_N))
        for (n in RECALL_CURVE_N) if (n < length(ids))
          curve[[paste(ag, rd, rule, m, n)]] <- data.table(agency = ag, reading = rd, rule = rule, method = m, N = n,
            recall = recall_at_n(ids, v, n)$value, n_positive = length(pos))
        if (!is.na(N_SHORTLIST)) {
          miss <- setdiff(pos, head(ids, N_SHORTLIST)); fp <- names(v)[!is.na(v) & !v & names(v) %in% head(ids, TOP_K_PRECISION)]
          detail[[paste(ag, rd, rule, m)]] <- data.table(agency = ag, reading = rd, rule = rule, method = m,
            kind = c(rep("positive_outside_top_N", length(miss)), rep("top10_labeled_not_positive", length(fp))), opp_id = c(miss, fp))
          sc <- methods[[m]]$scores
          if (!is.null(sc)) { t <- threshold_for_recall(sc, v, N_SHORTLIST, PASS_RECALL_AT_N)
            thr[[paste(ag, rd, rule, m)]] <- data.table(agency = ag, reading = rd, rule = rule, method = m, N = N_SHORTLIST,
              target_recall = PASS_RECALL_AT_N, positives_needed = t$k, threshold = t$threshold, reachable = t$reachable) }
        }
      }
      if (!is.null(ranking) && !is.na(N_SHORTLIST) && "ranker" %in% names(methods)) {
        rt <- head(methods$ranker$ids, N_SHORTLIST); bt <- head(methods$keyword_baseline$ids, N_SHORTLIST)
        a <- setdiff(intersect(pos, rt), bt); b <- setdiff(intersect(pos, bt), rt)
        detail[[paste(ag, rd, rule, "cmp")]] <- data.table(agency = ag, reading = rd, rule = rule, method = "ranker_vs_baseline",
          kind = c(rep("found_by_ranker_missed_by_baseline", length(a)), rep("found_by_baseline_missed_by_ranker", length(b))), opp_id = c(a, b))
      }
    }
  }
  S <- rbindlist(summ, fill = TRUE); C <- rbindlist(curve, fill = TRUE); D <- rbindlist(detail, fill = TRUE)
  G <- rbindlist(disag, fill = TRUE); T <- rbindlist(thr, fill = TRUE)
  fwrite(S, file.path(out_dir, "scores_summary.csv")); fwrite(C, file.path(out_dir, "recall_by_N.csv"))
  fwrite(D, file.path(out_dir, "scores_items_detail.csv")); fwrite(G, file.path(out_dir, "labeler_disagreements_to_discuss.csv"))
  fwrite(T, file.path(out_dir, "threshold_for_recall.csv"))
  options(width = 220)
  print(S[reading != "agreement", .(agency = substr(agency, 15, 40), reading, rule, method, recall_at_N, n_positive, precision_at_10_secondary = precision_at_10, labeled_in_top10, status)])
  cat("\nPrimary = recall in top N against the 70% bar (decision 12). Precision@10 is secondary.\n",
      "'Team-labelled' is not ground truth. Recall is only against the labeled pool; keyword-selected strata can overstate it (see pool_rules.md).\n", sep = "")
  invisible(list(summary = S, curve = C, detail = D, threshold = T))
}

if (sys.nframe() == 0 && !interactive() && length(grep("score_labels.R", commandArgs(FALSE))) > 0) score_main(commandArgs(TRUE))

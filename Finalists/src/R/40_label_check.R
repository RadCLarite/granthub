# 40_label_check.R: held-out check for the model labels (prompt evalpool-v3).
# Base R only (no packages), no outside calls. Run from Finalists/src/:
#   Rscript R/40_label_check.R stage=draw
#
# WHY: prompt v3 was written and gated on the 60 validate items (kappa 0.44, in-sample).
# A fair check needs items that were NOT used for that, labelled by people who never
# see model output. stage=draw makes those blind sheets. Nothing here fills a label,
# and the draw never looks at any model label.
#
# stage=draw   writes, in drafts/claude/docs/holdout/:
#   holdout_labeler_A.csv, holdout_labeler_B.csv   same 30 items, different order; blind
#   goals_for_labelers.md                          the agencies' plan goals, exact text
#   holdout_key_DO_NOT_OPEN.csv                    item_no -> opp_id and how it was drawn
# (stage=score comes after both sheets are filled; not written yet.)
#
# Draw rule (written before any label exists): per agency, from the open pool
# (status posted, forecasted or notice) minus the 60 validate items,
#   N_TOP    items with the most plan-goal words in title + summary (ties by opp_id), then
#   N_RANDOM items drawn at random from the rest (seeded).
# Known bias: the top-match half favours what keyword overlap finds, so recall can be
# overstated; the random half is the guard. About 30 items cannot prove anything: one
# item moves recall by several points.

here::i_am("src/R/40_label_check.R")
source(here::here("src", "R", "00_config.R"))   # holdout settings live there

args <- commandArgs(TRUE)
stage <- sub("^stage=", "", grep("^stage=", args, value = TRUE)[1])
if (is.na(stage) || !stage %in% c("draw", "score")) stop("Usage: Rscript R/40_label_check.R stage=draw|score")
if (!dir.exists("../data/processed")) stop("Run this from Finalists/src/.")
arg <- function(k, d) { m <- grep(paste0("^", k, "="), args, value = TRUE); if (length(m)) sub(paste0("^", k, "="), "", m[1]) else d }

# kappa for two logical vectors (no packages): (po - pe) / (1 - pe)
kappa_bin <- function(x, y) {
  po <- mean(x == y); pe <- mean(x) * mean(y) + (1 - mean(x)) * (1 - mean(y))
  if (isTRUE(all.equal(pe, 1))) return(NA_real_)
  (po - pe) / (1 - pe)
}

# ---- stage=score: run ONLY after both labelers have finished. -------------------------
# Reads the two filled sheets, the key, and the model labels (prompt evalpool-v3) of the
# same agencies from drafts/claude/eval/model_labels/by_agency/ (that folder is on main).
# Writes data/manual/label_holdout.csv (hand labels only) and a result report.
# The combining rule for two labelers is Kent's call, so BOTH readings are reported:
#   strict : hand "relevant" = both say relevant; yes/no (relevant+maybe vs not) is scored
#            only on items where the two labelers agree on it. Disagreements are listed.
#   lenient: hand "relevant" = either says relevant; yes = either says relevant or maybe.
# "Caught" = model says relevant OR maybe on a hand-relevant item (same rule as the validate
# report); the model-"relevant"-only share is reported too. Gate: catch >= 0.80 and kappa >= 0.60.
if (stage == "score") {
  hdir <- arg("holdout_dir", "../drafts/claude/docs/holdout")
  mdir <- arg("model_dir", "../drafts/claude/eval/model_labels/by_agency")
  out_csv <- arg("out", "../data/manual/label_holdout.csv")
  out_md <- arg("report", file.path(hdir, "label_check_result.md"))
  LV <- c("relevant", "maybe", "not relevant")
  rd <- function(f) read.csv(f, stringsAsFactors = FALSE, colClasses = "character", na.strings = character(0))
  A <- rd(file.path(hdir, "holdout_labeler_A.csv")); B <- rd(file.path(hdir, "holdout_labeler_B.csv"))
  key <- rd(file.path(hdir, "holdout_key_DO_NOT_OPEN.csv"))
  A$label <- trimws(tolower(A$label)); B$label <- trimws(tolower(B$label))
  for (nm in c("A", "B")) {
    s <- get(nm); bad <- !(s$label %in% LV)
    if (any(bad)) stop("Labeler ", nm, ": ", sum(bad), " of ", nrow(s), " labels are empty or not one of: ",
                       paste(LV, collapse = ", "), ". Finish the sheet first.")
  }
  h <- merge(A[, c("item_no", "label")], B[, c("item_no", "label")], by = "item_no", suffixes = c("_A", "_B"))
  h <- merge(h, key, by = "item_no"); stopifnot(nrow(h) == nrow(A), nrow(h) == nrow(B))
  slug <- function(ag) gsub("^_|_$", "", gsub("[^a-z]+", "_", tolower(ag)))
  h$model_label <- NA_character_; h$evidence_ok <- NA_character_
  for (ag in unique(h$agency)) {
    f <- file.path(mdir, paste0(slug(ag), ".csv"))
    if (!file.exists(f)) stop("No model labels for ", ag, " at ", f, ". Fetch main or finish that agency first.")
    ml <- rd(f); i <- h$agency == ag; j <- match(h$opp_id[i], ml$opp_id)
    if (anyNA(j)) stop(sum(is.na(j)), " held-out items missing from ", f)
    h$model_label[i] <- ml$model_label[j]; h$evidence_ok[i] <- ml$evidence_ok[j]
  }
  stopifnot(all(h$model_label %in% LV))
  h <- h[order(h$item_no), ]
  dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
  write.csv(h[, c("item_no", "agency", "opp_id", "source", "label_A", "label_B")], out_csv, row.names = FALSE)
  write.csv(h, file.path(hdir, "label_check_items.csv"), row.names = FALSE)

  yA <- h$label_A != "not relevant"; yB <- h$label_B != "not relevant"; mod <- h$model_label != "not relevant"
  readings <- list(
    strict = list(keep = yA == yB, hand_rel = h$label_A == "relevant" & h$label_B == "relevant", hand_yes = yA),
    lenient = list(keep = rep(TRUE, nrow(h)), hand_rel = h$label_A == "relevant" | h$label_B == "relevant", hand_yes = yA | yB))
  res <- lapply(names(readings), function(nm) {
    r <- readings[[nm]]; k <- r$keep; hr <- r$hand_rel & k
    data.frame(reading = nm, items_scored = sum(k), hand_relevant = sum(hr),
      caught_rel_or_maybe = sum(hr & mod), caught_model_relevant_only = sum(hr & h$model_label == "relevant"),
      catch_share = if (sum(hr) > 0) round(sum(hr & mod) / sum(hr), 3) else NA_real_,
      kappa_yes_no = round(kappa_bin(r$hand_yes[k], mod[k]), 3), stringsAsFactors = FALSE)
  })
  res <- do.call(rbind, res)
  res$gate <- ifelse(is.na(res$catch_share) | is.na(res$kappa_yes_no), "not computable",
                     ifelse(res$catch_share >= 0.80 & res$kappa_yes_no >= 0.60, "PASS", "FAIL"))
  k_AB <- round(kappa_bin(yA, yB), 3); agree3 <- round(mean(h$label_A == h$label_B), 3)
  dis <- h[h$label_A != h$label_B, c("item_no", "agency", "label_A", "label_B")]
  md <- c("# Held-out label check (model labels, prompt evalpool-v3)", "",
    paste0("1. ", nrow(h), " blind items, not used to write the prompt; two labelers (Noah, Matthew) labelled alone without seeing model output. Labelers agree on ", agree3 * 100, "% of items (binary kappa between them ", k_AB, ")."),
    paste0("2. Catch share of hand \"relevant\" (model relevant or maybe): strict ", res$catch_share[1], " (", res$caught_rel_or_maybe[1], " of ", res$hand_relevant[1], "), lenient ", res$catch_share[2], " (", res$caught_rel_or_maybe[2], " of ", res$hand_relevant[2], ")."),
    paste0("3. Kappa, relevant-plus-maybe vs not relevant: strict ", res$kappa_yes_no[1], ", lenient ", res$kappa_yes_no[2], ". Gate (catch 0.80, kappa 0.60): strict ", res$gate[1], ", lenient ", res$gate[2], "."), "",
    "How the set was made: `src/R/40_label_check.R stage=draw`. Per agency (Justice, Agriculture and Consumer Services, Labor), 5 items with the most plan-goal words in title and summary plus 5 random, from the open pool minus the 60 validate items. The draw never looked at a model label.", "",
    "Read before quoting: about 30 items, so one item moves the shares by several points; the top-match half favours what keyword overlap finds, so catch share can be overstated; two labelers show consistency, not ground truth. Which combining rule counts (strict or lenient) is Kent's call. Model labels stay out of the 1:00 payload either way.", "",
    "```", capture.output(print(res, row.names = FALSE)), "```", "",
    paste0("Items where the labelers disagree (", nrow(dis), "), to discuss; save any change as a new file:"), "",
    "```", capture.output(print(dis, row.names = FALSE)), "```")
  writeLines(md, out_md)
  cat(paste(md[3:5], collapse = "\n"), "\n\nWrote", out_csv, "and", out_md, "\n")
  quit(save = "no")
}

opps  <- read.csv("../data/processed/opportunities.csv", stringsAsFactors = FALSE,
                  colClasses = c(opp_id = "character", opp_number = "character"))
goals <- read.csv("docs/agency_goal_summaries.csv", stringsAsFactors = FALSE)
# ids of the 60 validate items, read ONLY to exclude them (no hand labels are read)
val_key <- read.csv("../drafts/claude/eval/sheets/key_hidden_DO_NOT_SHARE.csv", stringsAsFactors = FALSE,
                    colClasses = c(opp_id = "character"))
validate_ids <- unique(val_key$opp_id)
stopifnot(nrow(val_key) == 60)   # 60 items = 55 unique grants (5 appear under two agencies)

clean_text <- function(x) {
  x <- gsub("&amp;", "&", x, fixed = TRUE); x <- gsub("&#8217;|&#39;|&rsquo;", "'", x)
  x <- gsub("&#8211;|&ndash;", "-", x); x <- gsub("&quot;|&#8220;|&#8221;", "\"", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE); trimws(gsub("\\s+", " ", x))
}
or_unknown <- function(x) { x <- as.character(x); ifelse(is.na(x) | !nzchar(trimws(x)), "unknown", x) }
words_of <- function(x) unique(unlist(strsplit(tolower(gsub("[^A-Za-z ]", " ", x)), " +")))

pool <- opps[opps$status %in% POOL_STATUSES & !(opps$opp_id %in% validate_ids), ]
pool$text <- tolower(clean_text(paste(pool$title, pool$summary)))
cat("Pool after excluding validate items:", nrow(pool), "rows\n")

picked <- list()
for (ai in seq_along(HOLDOUT_AGENCIES)) {
  ag <- HOLDOUT_AGENCIES[ai]
  g <- goals[!is.na(goals$agency) & goals$agency == ag, ]
  if (nrow(g) == 0) stop("Agency not found in goals file: ", ag)
  terms <- setdiff(words_of(paste(g$goal_text_exact, collapse = " ")), c(GENERIC_WORDS))
  terms <- terms[nchar(terms) >= 5]
  pool$score <- vapply(pool$text, function(t) sum(vapply(terms, grepl, TRUE, x = t, fixed = TRUE)), 0)
  ord <- pool[order(-pool$score, pool$opp_id), ]
  top <- head(ord[ord$score > 0, ], N_TOP)
  rest <- sort(setdiff(pool$opp_id, top$opp_id))
  set.seed(HOLDOUT_SEED + ai)
  rnd_ids <- sample(rest, N_RANDOM)
  cat(ag, ":", length(terms), "goal words;", nrow(top), "top matches +", length(rnd_ids), "random\n")
  sel <- rbind(
    data.frame(agency = ag, opp_id = top$opp_id, source = "top_match", match_score = top$score, stringsAsFactors = FALSE),
    data.frame(agency = ag, opp_id = rnd_ids, source = "random", match_score = pool$score[match(rnd_ids, pool$opp_id)], stringsAsFactors = FALSE))
  picked[[ag]] <- sel
}
sel <- do.call(rbind, picked)
if (anyDuplicated(sel$opp_id)) {   # an item drawn for two agencies would be labelled twice; keep first
  sel <- sel[!duplicated(sel$opp_id), ]; warning("duplicate item across agencies removed")
}
set.seed(HOLDOUT_SEED + 100); sel <- sel[sample(nrow(sel)), ]
sel$item_no <- seq_len(nrow(sel))
m <- merge(sel, opps, by = "opp_id", sort = FALSE); m <- m[order(m$item_no), ]
stopifnot(nrow(m) == nrow(sel), !any(m$opp_id %in% validate_ids))

is_notice <- m$status == "notice"
cd <- suppressWarnings(as.Date(m$close_date))
close_txt <- ifelse(is_notice, "no deadline (notice)", ifelse(is.na(cd), "no date listed",
             ifelse(cd >= FAR_FUTURE_DATE, "rolling or no date listed", format(cd))))
aw <- suppressWarnings(as.numeric(m$award_ceiling))
award_txt <- ifelse(is_notice, "none (notice)", ifelse(is.na(aw), "unknown",
             ifelse(aw == 0, "unknown (listed as 0)", format(aw, scientific = FALSE, big.mark = ","))))
base <- data.frame(item_no = m$item_no, agency_for_fit = m$agency.x, opp_number = m$opp_number,
  title = clean_text(m$title), funder = clean_text(or_unknown(m$agency.y)), status = m$status,
  close_date = close_txt, award_ceiling = award_txt,
  summary_short = substr(clean_text(or_unknown(m$summary)), 1, SUMMARY_CHARS), url = or_unknown(m$url),
  stringsAsFactors = FALSE)

out_dir <- "../drafts/claude/docs/holdout"; dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
for (lb in c("A", "B")) {
  sh <- base
  if (lb == "B") { set.seed(HOLDOUT_SEED + 200); sh <- sh[sample(nrow(sh)), ] }
  sh$labeler <- lb; sh$label <- ""; sh$note <- ""   # label: relevant / maybe / not relevant
  write.csv(sh, file.path(out_dir, paste0("holdout_labeler_", lb, ".csv")), row.names = FALSE, na = "")
}
write.csv(data.frame(item_no = sel$item_no, agency = sel$agency, opp_id = sel$opp_id,
                     source = sel$source, match_score = sel$match_score),
          file.path(out_dir, "holdout_key_DO_NOT_OPEN.csv"), row.names = FALSE)

gl <- c("# Plan goals for the held-out labelers", "",
  "Exact text from each agency's strategic plan (`src/docs/agency_goal_summaries.csv`). Label every item for the agency named in its `agency_for_fit` column.",
  "", "- **relevant**: this agency's grant writer would want to look at it.",
  "- **maybe**: unclear from the notice.", "- **not relevant**: no.", "",
  "Work alone. Do not open any model output, rank, score or the key file. AI must not fill, suggest or check a label.", "")
for (ag in HOLDOUT_AGENCIES) {
  g <- goals[!is.na(goals$agency) & goals$agency == ag, ]
  gl <- c(gl, paste0("## ", ag), "", paste0("- ", gsub("\\s+", " ", g$goal_text_exact)), "")
}
writeLines(gl, file.path(out_dir, "goals_for_labelers.md"))
cat("Wrote", nrow(base), "items to", out_dir, "\n")
print(table(sel$agency, sel$source))

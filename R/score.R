# score.R: filter, score, rank, explain. Pure functions, no side effects when sourced.
#
# The criteria table (data/manual/criteria.csv) is the whole method. One row per
# criterion; the client's words go in `source`, the plain-language reason in `why`.
#
#   id          short key, no spaces (used as a column name)
#   type        filter (drops an item the user cannot use) | score (adds points)
#   label       what the user sees
#   field       column in the items table
#   rule        eq neq in not_in gte lte between contains is_true not_na
#               date_gte_days date_lte_days scale (score only)
#   value       rule argument; lists and ranges use "|", e.g. "a|b" or "0|100000"
#   weight      score rows only; share of the total (0 turns the criterion off)
#   if_missing  filter: fail | pass (default fail). score: drop | zero | half (default drop)
#               drop = leave this part out and rescale the other weights (decision 5)
#   why         one plain sentence a non-technical reader would accept
#   source      where the criterion came from (workshop quote, plan page, mentor)
#
# Each score criterion gives an item 0 to 1. Total = 100 * sum(weight * points) / sum(weight),
# over the parts the item has data for. An item with no data for any weighted part gets an
# NA total and ranks last. All weights zero is an error (it would rank nothing).
# Requires dplyr, stringr, purrr, tibble.

suppressPackageStartupMessages({ library(dplyr); library(stringr); library(purrr); library(tibble) })

RULES_FILTER <- c("eq", "neq", "in", "not_in", "gte", "lte", "between", "contains",
                  "is_true", "not_na", "date_gte_days", "date_lte_days")
RULES_SCORE  <- c(RULES_FILTER, "scale")

.vals <- function(v) trimws(strsplit(as.character(v), "|", fixed = TRUE)[[1]])
.num  <- function(x) suppressWarnings(as.numeric(x))

# Evaluate one rule on a vector. Returns logical (or numeric 0..1 for scale); NA = missing data.
rule_eval <- function(x, rule, value, ref_date) {
  v <- .vals(value)
  na <- is.na(x)
  out <- switch(rule,
    eq     = as.character(x) == v[1],
    neq    = as.character(x) != v[1],
    `in`   = as.character(x) %in% v,
    not_in = !(as.character(x) %in% v),
    gte    = .num(x) >= .num(v[1]),
    lte    = .num(x) <= .num(v[1]),
    between = .num(x) >= .num(v[1]) & .num(x) <= .num(v[2]),
    contains = Reduce(`|`, lapply(v, function(p) str_detect(as.character(x), fixed(p, ignore_case = TRUE)))),
    is_true = tolower(as.character(x)) %in% c("true", "t", "yes", "y", "1"),
    not_na = !na & nzchar(as.character(x)),
    date_gte_days = as.Date(x) >= ref_date + .num(v[1]),
    date_lte_days = as.Date(x) <= ref_date + .num(v[1]),
    scale = {
      lo <- .num(v[1]); hi <- .num(v[2])
      if (lo == hi) stop("scale rule needs two different ends: ", value)
      pmin(1, pmax(0, (.num(x) - lo) / (hi - lo)))
    },
    stop("Unknown rule: ", rule))
  if (rule != "not_na") out[na] <- NA
  out
}

validate_criteria <- function(cr, items) {
  need <- c("id", "type", "label", "field", "rule", "value")
  miss <- setdiff(need, names(cr))
  if (length(miss)) stop("criteria is missing columns: ", paste(miss, collapse = ", "))
  if (anyDuplicated(cr$id)) stop("criteria ids must be unique")
  if (any(!cr$type %in% c("filter", "score"))) stop("type must be filter or score")
  bad <- cr$type == "filter" & !cr$rule %in% RULES_FILTER
  if (any(bad)) stop("rule not allowed for a filter: ", paste(cr$rule[bad], collapse = ", "))
  bad <- cr$type == "score" & !cr$rule %in% RULES_SCORE
  if (any(bad)) stop("rule not allowed for a score: ", paste(cr$rule[bad], collapse = ", "))
  nofield <- setdiff(cr$field, names(items))
  if (length(nofield)) stop("criteria point at columns that are not in the items: ", paste(nofield, collapse = ", "))
  if (any(cr$type == "score") && !"weight" %in% names(cr)) stop("score criteria need a weight column")
  invisible(TRUE)
}

# Per item: which filters it fails (missing data resolved by if_missing) and 0..1 points.
evaluate_criteria <- function(items, cr, ref_date) {
  validate_criteria(cr, items)
  if (!"if_missing" %in% names(cr)) cr$if_missing <- NA_character_
  fails <- list(); pts <- list(); missing <- list()
  for (i in seq_len(nrow(cr))) {
    r <- cr[i, ]
    res <- rule_eval(items[[r$field]], r$rule, r$value, ref_date)
    miss <- is.na(res)
    if (r$type == "filter") {
      pass_if_missing <- identical(r$if_missing, "pass")
      res[miss] <- pass_if_missing
      fails[[r$id]] <- !res
    } else {
      p <- if (is.logical(res)) as.numeric(res) else res
      p[miss] <- switch(if (is.na(r$if_missing)) "drop" else r$if_missing,
                        zero = 0, half = 0.5, drop = NA_real_, stop("if_missing for a score must be drop, zero or half: ", r$id))
      pts[[r$id]] <- p
    }
    missing[[r$id]] <- miss
  }
  list(fails = as_tibble(fails), pts = as_tibble(pts), missing = as_tibble(missing))
}

fmt2 <- function(x) formatC(x, format = "f", digits = 2)

# One sentence per item: what pulled it up and what held it back.
explain_row <- function(p, w, labels) {
  use <- w > 0
  if (!any(use)) return("No score criteria are on.")
  p <- p[use]; w <- w[use]; labels <- labels[use]
  unk <- is.na(p)
  note <- if (any(unk)) paste0(". Unknown: ", paste(labels[unk], collapse = ", ")) else ""
  if (all(unk)) return(paste0("No score could be computed", note))
  p <- p[!unk]; w <- w[!unk]; labels <- labels[!unk]
  contrib <- w * p
  top <- order(-contrib, labels, method = "radix")
  strong <- top[p[top] > 0][seq_len(min(2, sum(p > 0)))]
  weak <- order(p, -w, labels, method = "radix")
  weak <- setdiff(weak[p[weak] < 1], strong)
  weak <- weak[seq_len(min(1, length(weak)))]
  s <- if (length(strong)) paste0("Strong: ", paste0(labels[strong], " (", fmt2(p[strong]), ")", collapse = ", ")) else "No strong points"
  k <- if (length(weak)) paste0(". Weak: ", labels[weak], " (", fmt2(p[weak]), ")") else ""
  paste0(s, k, note)
}

# Filter, score, rank, explain. `weights` (named by criterion id) and `filters_on` (named
# logical) override the criteria table, which is how the tool's sliders work.
rank_items <- function(items, cr, ref_date, id_col = "id", name_col = "name",
                       weights = NULL, filters_on = NULL, top_n = Inf) {
  if (anyDuplicated(items[[id_col]])) stop("item ids must be unique; duplicated: ",
    paste(head(unique(items[[id_col]][duplicated(items[[id_col]])]), 5), collapse = ", "))
  ev <- evaluate_criteria(items, cr, ref_date)
  filt <- cr[cr$type == "filter", ]; sc <- cr[cr$type == "score", ]
  w <- setNames(.num(sc$weight), sc$id)
  if (!is.null(weights)) w[names(weights)] <- weights
  on <- setNames(rep(TRUE, nrow(filt)), filt$id)
  if (!is.null(filters_on)) on[names(filters_on)] <- filters_on

  failed_on <- if (nrow(filt)) vapply(seq_len(nrow(items)), function(i)
    paste(filt$id[unlist(ev$fails[i, filt$id]) & on[filt$id]], collapse = "; "), character(1)) else rep("", nrow(items))
  passed <- failed_on == ""

  if (length(w) && sum(w) <= 0) stop("All score weights are zero: nothing to rank by. Give at least one score criterion a weight above 0.")
  if (length(w)) {
    P <- as.matrix(ev$pts)[, names(w), drop = FALSE]
    num <- rowSums(sweep(P, 2, w, `*`), na.rm = TRUE)
    den <- as.vector((!is.na(P)) %*% w)
    total <- ifelse(den > 0, 100 * num / den, NA_real_)
    why <- vapply(seq_len(nrow(items)), function(i)
      explain_row(P[i, ], w, sc$label[match(names(w), sc$id)]), character(1))
  } else {                                   # filter-only table: nothing to score
    P <- matrix(numeric(0), nrow(items), 0); total <- rep(0, nrow(items))
    why <- rep("No score criteria are on.", nrow(items))
  }

  all <- tibble(id = as.character(items[[id_col]]), name = as.character(items[[name_col]]),
                total = round(total, 4), passed = passed, dropped_by = failed_on, why = why)
  pts_cols <- setNames(as_tibble(P), paste0("pts_", colnames(P)))
  all <- bind_cols(all, pts_cols)
  ranked <- all[all$passed, ]
  ranked <- ranked[order(is.na(ranked$total), -ranked$total, ranked$id, method = "radix"), ]
  ranked$rank <- seq_len(nrow(ranked))
  if (is.finite(top_n)) ranked <- ranked[ranked$rank <= top_n, ]
  list(ranked = ranked, dropped = all[!all$passed, c("id", "name", "dropped_by")],
       all = all, eval = ev, weights = w, filters_on = on)
}

# Everything the single-file tool needs, with the same numbers R computed.
build_payload <- function(items, cr, rk, id_col, name_col, show_fields) {
  filt <- cr[cr$type == "filter", ]; sc <- cr[cr$type == "score", ]
  ev <- rk$eval
  rows <- lapply(seq_len(nrow(items)), function(i) {
    fields <- lapply(show_fields, function(f) {
      v <- items[[f]][i]
      if (is.numeric(v) && !is.na(v)) format(v, scientific = FALSE, big.mark = ",", trim = TRUE) else as.character(v)
    })
    names(fields) <- show_fields
    list(id = as.character(items[[id_col]][i]), name = as.character(items[[name_col]][i]),
         fields = fields,
         fails = I(filt$id[unlist(ev$fails[i, filt$id])]),   # I() keeps a one-element list a JSON array
         pts = as.list(setNames(unlist(ev$pts[i, sc$id]), sc$id)))
  })
  list(
    title = PROJECT_TITLE, subtitle = PROJECT_SUB, ref_date = as.character(REF_DATE),
    show_fields = show_fields,
    criteria = lapply(seq_len(nrow(cr)), function(i) as.list(cr[i, c("id", "type", "label", "why", "source", if ("weight" %in% names(cr)) "weight")])),
    config = list(top_n = TOP_N, weight_range = WEIGHT_RANGE, weight_step = WEIGHT_STEP),
    items = rows)
}

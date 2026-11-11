# helpers_rank.R: turn opportunities.csv and the agency goal table into the
# agency x opportunity table that score.R ranks. Pure functions; sourced by
# 10_run_ranking.R and the tests. Thresholds come from 00_config.R.
#
# Keyword fit is TF-IDF cosine between one opportunity (title + summary) and an agency's
# full plan text, centered per opportunity (see build_pairs). `fit_fn` is the one swappable scoring function:
# Azure embeddings can replace keyword_fit() without touching anything else.
# Requires dplyr, stringr, Matrix.

suppressPackageStartupMessages({ library(dplyr); library(stringr); library(Matrix); library(readr) })

# Short English stop list; IDF over the whole corpus takes care of grant boilerplate.
STOPWORDS <- c("the", "and", "for", "with", "that", "this", "from", "are", "will", "its", "our",
               "their", "into", "all", "each", "not", "but", "can", "has", "have", "been", "who",
               "which", "these", "those", "such", "than", "they", "them", "also", "may", "any",
               "other", "more", "most", "through", "within", "under", "over", "about", "between",
               "was", "were", "you", "your", "his", "her", "how", "what", "when", "where", "while",
               "goal", "goals", "objective", "pillar", "priority", "nbsp", "amp", "http", "https", "www")

kw_tokenize <- function(x) {
  x <- tolower(ifelse(is.na(x), "", x))
  toks <- strsplit(str_replace_all(x, "[^a-z]+", " "), " ", fixed = TRUE)
  lapply(toks, function(t) {
    t <- t[nchar(t) >= 3 & !t %in% STOPWORDS]
    t <- sub("ies$", "y", t)
    sub("([^su])s$", "\\1", t)          # crude plural strip: grants -> grant, keeps "class", "status"
  })
}

# Rows of a sparse TF-IDF matrix, L2-normalised. Sublinear tf (1 + log tf).
tfidf <- function(tok_list, vocab, idf) {
  i <- rep(seq_along(tok_list), lengths(tok_list))
  j <- match(unlist(tok_list), vocab)
  keep <- !is.na(j)
  m <- sparseMatrix(i = i[keep], j = j[keep], x = 1, dims = c(length(tok_list), length(vocab)))
  m@x <- 1 + log(m@x)
  m <- m %*% Diagonal(x = idf)
  norms <- sqrt(rowSums(m^2)); norms[norms == 0] <- 1
  Diagonal(x = 1 / norms) %*% m
}

# opp_text, goal_text: character vectors. Returns a dense opp x goal cosine matrix.
keyword_fit <- function(opp_text, goal_text) {
  ot <- kw_tokenize(opp_text); gt <- kw_tokenize(goal_text)
  all_t <- c(ot, gt)
  vocab <- sort(unique(unlist(all_t)))
  df <- tabulate(match(unlist(lapply(all_t, unique)), vocab), nbins = length(vocab))
  idf <- log((1 + length(all_t)) / (1 + df)) + 1
  as.matrix(tfidf(ot, vocab, idf) %*% t(tfidf(gt, vocab, idf)))
}

# Clean opportunities: unique ids, ceiling 0 is unknown, far-future and past forecast dates
# become unknown with a note, days left from the reference date.
prep_opportunities <- function(opps, ref_date, far_future = FAR_FUTURE_DATE) {
  opps <- opps[!duplicated(opps$opp_id), ]
  cd <- as.Date(opps$close_date)
  ceiling <- suppressWarnings(as.numeric(opps$award_ceiling))
  opps |> mutate(
    award_ceiling = ifelse(!is.na(ceiling) & ceiling > 0, ceiling, NA_real_),
    log_ceiling = log10(award_ceiling),
    date_note = case_when(
      is.na(cd) | cd >= far_future ~ "rolling or no date listed",
      status == "forecasted" & cd < ref_date ~ "date listed has passed",
      TRUE ~ NA_character_),
    close_date = if_else(is.na(date_note), cd, as.Date(NA)),
    days_left = as.integer(close_date - ref_date),
    opp_text = paste(title, ifelse(is.na(summary), "", summary)))
}

# Active agencies and their goals (folded plans join their target; dropped plans leave).
agency_goals <- function(goals, amap) {
  amap <- amap |> mutate(target = coalesce(fold_into, agency_id))
  goals |>
    inner_join(filter(amap, is.na(drop_reason)) |> select(plan_file, agency_id = target), by = "plan_file") |>
    filter(is.na(duplicate_of_row)) |>
    mutate(goal_text = str_squish(paste(goal_text_exact, coalesce(goal_statement, ""))),
           goal_key = paste(agency_id, plan_file, goal_id, sep = "|"))
}

# Full plan text per active agency (folded plans join their target agency).
plan_texts <- function(amap, dir_text) {
  am <- amap |> filter(is.na(drop_reason)) |> mutate(target = coalesce(fold_into, agency_id))
  sapply(split(am$plan_file, am$target), function(f)
    paste(unlist(lapply(file.path(dir_text, sub("pdf$", "txt", f)), readLines, warn = FALSE)), collapse = " "))
}

# One row per agency x opportunity.
# fit: keyword fit of the opportunity to the agency's FULL plan, centered per opportunity
# (minus its mean fit over all agencies, so boilerplate that matches every plan cancels),
# floored at 0 and divided by the agency's best, giving 0..1. Goal headings alone ranked
# badly in testing (see AI_USAGE_LOG.md), so goal_id and goal_snippet are display only:
# the best-matching goal heading for that pair.
build_pairs <- function(opps, ag, plans, fit_fn = keyword_fit) {
  sim <- fit_fn(opps$opp_text, plans)
  colnames(sim) <- names(plans)
  cen <- sim - rowMeans(sim)
  gsim <- fit_fn(opps$opp_text, ag$goal_text)
  out <- lapply(names(plans), function(a) {
    raw <- pmax(cen[, a], 0); top <- max(raw)
    cols <- which(ag$agency_id == a)
    gs <- gsim[, cols, drop = FALSE]
    best <- max.col(gs, ties.method = "first")
    has <- gs[cbind(seq_len(nrow(gs)), best)] > 0
    tibble(agency_id = a, opp_id = opps$opp_id,
           fit_raw = cen[, a], fit = if (top > 0) raw / top else 0,
           goal_id = ifelse(has, ag$goal_id[cols[best]], NA),
           goal_snippet = ifelse(has, ag$goal_text_exact[cols[best]], NA))
  })
  bind_rows(out)
}

# ---- Eligibility ------------------------------------------------------------------
# Step 2, fixed text rules, per opportunity. Returns "yes" / "no" / NA (undecided) and the
# exact matched text as the quote. A "no" phrase wins; "yes" phrases are void when a
# negation sits just before them.
text_eligibility <- function(text) {
  t <- ifelse(is.na(text), "", text)
  no_re  <- regex(paste(ELIG_TEXT_NO, collapse = "|"), ignore_case = TRUE)
  yes_re <- regex(paste(ELIG_TEXT_YES, collapse = "|"), ignore_case = TRUE)
  neg_re <- regex(ELIG_TEXT_NEGATION, ignore_case = TRUE)
  no_q <- str_extract(t, no_re); neg_q <- str_extract(t, neg_re); yes_q <- str_extract(t, yes_re)
  call <- case_when(!is.na(no_q) | !is.na(neg_q) ~ "no", !is.na(yes_q) ~ "yes", TRUE ~ NA_character_)
  tibble(text_call = call, text_quote = coalesce(no_q, neg_q, yes_q))
}

# Step 1 (codes) then step 2 (text) per agency x opportunity.
# Returns eligibility yes | no | ask, elig_source code | rule, elig_quote (exact text or NA).
assign_eligibility <- function(agency_id, codes, text) {
  has <- function(c) vapply(codes, function(x) !is.na(x) && any(strsplit(x, "|", fixed = TRUE)[[1]] %in% c), logical(1))
  yes_code <- has(ELIG_YES_CODES)
  he_ok <- has(ELIG_HIGHER_ED_CODE) & agency_id %in% ELIG_HIGHER_ED_AGENCIES
  ask_code <- has(ELIG_ASK_CODES) | is.na(codes) | codes == ""
  tx <- text_eligibility(text)
  decided <- !is.na(tx$text_call)
  tibble(
    # A text phrase can rule an item out but never confirm it: "state governments" also appears in lists
    # of who is NOT the target (EPSCoR, Fair Housing). Text "yes" stays "ask" with its quote shown.
    eligibility = case_when(yes_code | he_ok ~ "yes", ask_code & decided & tx$text_call == "no" ~ "no",
                            ask_code ~ "ask", TRUE ~ "no"),
    elig_source = case_when(yes_code | he_ok ~ "code", ask_code & decided ~ "rule", TRUE ~ "code"),
    elig_quote  = if_else(!(yes_code | he_ok) & ask_code & decided, tx$text_quote, NA_character_))
}

# Tribal-program title on an item still marked "ask" -> "no" with the title words as the quote.
tribal_title_rule <- function(elig, title) {
  t <- ifelse(is.na(title), "", title)
  q <- str_extract(t, regex(ELIG_TRIBAL_TITLE, ignore_case = TRUE))
  hit <- elig$eligibility == "ask" & !is.na(q) & !str_detect(t, regex("\\bStates?\\b", ignore_case = TRUE))
  elig$eligibility[hit] <- "no"; elig$elig_source[hit] <- "rule"; elig$elig_quote[hit] <- paste0("Title: ", q[hit])
  elig
}

# Display text: decode numeric HTML entities (&#8211;), drop zero-width characters, turn narrow and
# no-break spaces into spaces, split PDF ligatures (fi, fl, ff) so snippets read cleanly.
clean_text <- function(x) {
  x <- ifelse(is.na(x), NA_character_, x)
  dec <- function(s) {
    if (is.na(s)) return(s)
    m <- gregexpr("&#[0-9]+;", s)[[1]]
    if (m[1] == -1) return(s)
    for (e in unique(regmatches(s, list(m))[[1]])) {
      cp <- as.integer(gsub("[^0-9]", "", e))
      r <- if (cp %in% c(8203L, 65279L)) "" else if (cp %in% c(8239L, 160L)) " " else intToUtf8(cp)
      s <- gsub(e, r, s, fixed = TRUE)
    }
    s
  }
  x <- vapply(x, dec, character(1), USE.NAMES = FALSE)
  for (lig in list(c("\ufb00", "ff"), c("\ufb01", "fi"), c("\ufb02", "fl"), c("\ufb03", "ffi"), c("\ufb04", "ffl")))
    x <- gsub(lig[1], lig[2], x, fixed = TRUE)
  str_squish(x)
}

# TRUE when a title names another US state or region and not North Carolina.
geo_other <- function(title) {
  t <- ifelse(is.na(title), "", title)
  other <- str_detect(t, regex(paste0("\\b(", paste(GEO_OTHER_PLACES, collapse = "|"), ")\\b"), ignore_case = TRUE))
  other & !str_detect(t, regex("\\bNorth Carolina\\b|\\bNC\\b", ignore_case = TRUE))
}

# TRUE when the funder is a U.S. Embassy, Mission or Consulate abroad (see OVERSEAS_POST_PATTERN).
overseas_post <- function(funder) {
  !is.na(funder) & str_detect(funder, regex(OVERSEAS_POST_PATTERN, ignore_case = TRUE))
}

# Program map: adds map_note and lifts fit to MAP_FIT_FLOOR for agency x Assistance Listing pairs in the table.
apply_program_map <- function(items, cfda_list, pmap) {
  hit <- vapply(seq_len(nrow(items)), function(i) {
    m <- pmap$why[pmap$agency_id == items$agency_id[i] & pmap$cfda %in% strsplit(cfda_list[i], "[|,; ]+")[[1]]]
    if (length(m)) m[1] else NA_character_
  }, character(1))
  items$map_note <- hit
  items$fit <- ifelse(!is.na(hit), pmax(items$fit, MAP_FIT_FLOOR), items$fit)
  items
}

# Signature tier from notice fields only (who has to sign), following the qualifier's rules that need
# nothing but cost share and award size. No model, no text guess: a missing cost-share field stays unknown.
#   Yes and award >= TIER_APPROPRIATION_USD -> leadership   (likely needs a state appropriation)
#   Yes otherwise                            -> supervisor   (a supervisor must approve the match)
#   No                                       -> writer       (no match; capabilities not checked, so "can start" only)
# Returns signature_tier, tier_source ("fields" or NA) and tier_reason (one plain sentence or NA).
signature_tier <- function(cost_sharing, award_ceiling, appropriation = TIER_APPROPRIATION_USD) {
  cs <- tolower(trimws(as.character(cost_sharing))); aw <- suppressWarnings(as.numeric(award_ceiling))
  big <- !is.na(aw) & aw > 0 & aw >= appropriation
  tier <- case_when(cs == "yes" & big ~ "leadership", cs == "yes" ~ "supervisor", cs == "no" ~ "writer", TRUE ~ "unknown")
  tibble(signature_tier = tier,
         tier_source = ifelse(tier == "unknown", NA_character_, "fields"),
         tier_reason = case_when(
           tier == "leadership" ~ paste0("Cost share is required on an award of about $", format(aw, big.mark = ",", scientific = FALSE),
                                         ", which likely needs a state appropriation."),
           tier == "supervisor" ~ "Cost share is required, so a supervisor must approve the match.",
           tier == "writer" ~ "No cost share is listed; capabilities are not checked here.",
           TRUE ~ NA_character_))
}

# One sentence on how a row's keyword fit was reached, from the fields that moved it.
rank_note <- function(fit, rank, in_top10, map_note, geo_other, n_open) {
  f <- suppressWarnings(round(100 * as.numeric(fit)))
  base <- ifelse(is.na(f), "No keyword fit could be computed.",
    paste0("Keyword fit ", f, " of 100 against this agency's best match",
           ifelse(!is.na(rank) & in_top10, paste0("; rank ", rank, " of ", n_open, " open eligible items"), ""), "."))
  paste0(base,
    ifelse(!is.na(map_note) & map_note != "", paste0(" Raised to at least ", round(100 * MAP_FIT_FLOOR), " by the program map: ", map_note), ""),
    ifelse(!is.na(geo_other) & geo_other, " Halved because the title names another state.", ""))
}

# ---- Shared steps for 10_run_ranking.R, 11_build_payload.R and 12_backtest.R ------------
read_criteria <- function(path = CRITERIA_FILE) {
  cr <- read_csv(path, show_col_types = FALSE, col_types = cols(.default = col_character()))
  cr$weight <- if ("weight" %in% names(cr)) suppressWarnings(as.numeric(cr$weight)) else NA_real_
  cr
}

# Cleaned opportunities (all statuses), the agency goal table and the full plan texts.
load_rank_inputs <- function(ref_date = REF_DATE) {
  chr <- cols(.default = col_character())
  amap <- read_csv(AGENCY_MAP_FILE, show_col_types = FALSE, col_types = chr)
  opps <- prep_opportunities(read_csv(OPPS_FILE, show_col_types = FALSE, col_types = chr), ref_date)
  opps$post_date <- as.Date(opps$post_date)
  list(opps = opps, amap = amap,
       pmap = read_csv(PROGRAM_MAP_FILE, show_col_types = FALSE, col_types = chr),
       ag = agency_goals(read_csv(GOALS_FILE, show_col_types = FALSE, col_types = chr), amap),
       plans = plan_texts(amap, file.path(DIR_PROCESSED, "agency_plan_text", "all")))
}

# One row per agency x opportunity with fit, goal match, dates, award and eligibility.
build_items <- function(opps, ag, plans, pmap) {
  items <- build_pairs(opps, ag, plans) |>
    left_join(opps[, c("opp_id", "opp_number", "title", "status", "post_date", "close_date", "date_note", "days_left",
                       "award_ceiling", "log_ceiling", "cost_sharing", "applicant_types", "eligibility_text")], by = "opp_id") |>
    mutate(id = paste(agency_id, opp_id, sep = ":"))
  items <- bind_cols(items, tribal_title_rule(assign_eligibility(items$agency_id, items$applicant_types, items$eligibility_text), items$title))
  items$eligibility_text <- NULL
  items$geo_other <- geo_other(items$title)
  items$overseas_post <- overseas_post(opps$agency[match(items$opp_id, opps$opp_id)])
  items$fit <- ifelse(items$geo_other, items$fit * GEO_PENALTY, items$fit)
  apply_program_map(items, opps$cfda_list[match(items$opp_id, opps$opp_id)], pmap)
}

# Rank inside each agency (needs score.R sourced). Returns the ranked and dropped rows with agency_id.
rank_by_agency <- function(items, cr, ref_date = REF_DATE) {
  res <- lapply(split(items, items$agency_id), function(it) rank_items(it, cr, ref_date, ID_COL, NAME_COL, top_n = Inf))
  tag <- function(part) bind_rows(lapply(names(res), function(a) mutate(res[[a]][[part]], agency_id = a, .before = 1)))
  list(ranked = tag("ranked"), dropped = tag("dropped"))
}


# ---- Who a grant reaches (display only) ------------------------------------------------------
# tag_groups(title, summary): for each grant, up to REACH_MAX_GROUPS population groups from GROUP_RULES,
# title matches first, each with the words it matched as a quote. Phrases in GROUP_IGNORE (boilerplate,
# "aging infrastructure") are blanked before matching. Returns a list of data frames (id, quote).
mask_ignored <- function(x, ignore = GROUP_IGNORE) {
  m <- gregexpr(ignore, x, ignore.case = TRUE, perl = TRUE)
  regmatches(x, m) <- lapply(regmatches(x, m), function(v) strrep(" ", nchar(v)))
  x
}
tag_groups <- function(title, summary, rules = GROUP_RULES, max_n = REACH_MAX_GROUPS, qchars = REACH_QUOTE_CHARS, ignore = GROUP_IGNORE) {
  hits <- function(x) { mx <- mask_ignored(x, ignore); names(rules)[vapply(rules, function(r) grepl(r, mx, ignore.case = TRUE, perl = TRUE), logical(1))] }
  quote_from <- function(txt, pat) {
    ss <- trimws(unlist(strsplit(txt, "(?<=[.!?])\\s+", perl = TRUE)))
    ms <- mask_ignored(ss, ignore)
    k <- which(grepl(pat, ms, ignore.case = TRUE, perl = TRUE))[1]
    if (is.na(k)) return(NA_character_)
    hit <- ss[k]
    if (nchar(hit) <= qchars) return(hit)
    # long sentence: a window centred on the matched words, so the evidence is visible
    m <- regexpr(pat, ms[k], ignore.case = TRUE, perl = TRUE); half <- (qchars - attr(m, "match.length")) %/% 2
    from <- max(1L, m - half); to <- min(nchar(hit), from + qchars - 1L); from <- max(1L, to - qchars + 1L)
    paste0(if (from > 1) "\u2026" else "", trimws(substr(hit, from, to)), if (to < nchar(hit)) "\u2026" else "")
  }
  Map(function(ti, su) {
    ti <- ifelse(is.na(ti), "", ti); su <- ifelse(is.na(su), "", su)
    in_title <- hits(ti); in_sum <- setdiff(hits(su), in_title)
    ids <- head(c(in_title, in_sum), max_n)
    if (!length(ids)) return(data.frame(id = character(0), quote = character(0)))
    q <- vapply(ids, function(g) if (g %in% in_title) ti else quote_from(su, rules[[g]]), character(1))
    data.frame(id = ids, quote = unname(q))
  }, title, summary, USE.NAMES = FALSE)
}

# Size in bytes of plan text files with each CRLF counted as one LF, so the figure is the same on a Windows checkout
# (CRLF, git autocrlf) and on Linux (LF). A missing file counts as zero. Used for plan_thin (11_build_payload.R).
plan_text_bytes <- function(paths) {
  sum(vapply(paths, function(p) {
    if (!file.exists(p)) return(0)
    x <- readBin(p, "raw", file.size(p))
    n <- length(x)
    if (n == 0) return(0)
    n - if (n > 1) sum(x[-n] == as.raw(13) & x[-1] == as.raw(10)) else 0
  }, numeric(1)))
}

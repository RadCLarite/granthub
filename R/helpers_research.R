# helpers_research.R: parsers and the pool rule for the researcher tab (research.json).
# Pure functions; no file writes. Used by 14_build_research_payload.R and tests/test_research.R.

RESEARCH_ELIGIBLE_CODES <- c("06", "12", "13", "20", "22", "23", "25", "99")  # higher-ed and nonprofit applicant types
RESEARCH_SUM_MAX <- 1200L

# Activity code (R01, U24, R43, SBIR...) from an NIH title; NA when none.
parse_mechanism <- function(title) {
  title <- as.character(title)
  in_paren <- vapply(stringr::str_match_all(title, "[(]([^)]*)[)]"), function(m) {
    hit <- stringr::str_match(m[, 2], "^(?:Parent |Collaborative )?((?!FY)[CDFGKLMNPRSTUXZ][0-9]{2}|(?!FY)[CDFGKLMNPRSTUXZ][A-Z][0-9]{1,2}|SBIR|STTR)\\b")[, 2]
    hit <- hit[!is.na(hit)]
    if (length(hit)) hit[1] else NA_character_
  }, character(1))
  loose <- stringr::str_extract(title, "\\b(?:[RKUPTFDS][0-9]{2}|U[GHMT][0-9]|RM1|DP[0-9])\\b")
  dplyr::coalesce(in_paren, loose)
}

# Clinical-trial status stated in the title: required, optional, not_allowed, or NA.
parse_trial_status <- function(text) {
  t <- tolower(as.character(text))
  dplyr::case_when(
    grepl("clinical trials? not allowed", t) ~ "not_allowed",
    grepl("clinical trials? optional", t) ~ "optional",
    grepl("clinical trials? required", t) ~ "required",
    TRUE ~ NA_character_)
}

# Human-subjects flag: "trial" when the title says a trial is required or optional, "mentioned" when the text names human subjects.
parse_hs_flag <- function(text, trial) {
  text <- tolower(as.character(text))
  dplyr::case_when(
    !is.na(trial) & trial %in% c("required", "optional") ~ "trial",
    grepl("human subjects?", text) ~ "mentioned",
    TRUE ~ NA_character_)
}

.nih_ic_codes <- function() readr::read_csv(here::here("data", "manual", "nih_ic_codes.csv"), col_types = "cc", show_col_types = FALSE)$ic

# Two-letter NIH institute code: from RFA-AG-26-020 style numbers, else a funding_activity value that is a known IC code.
parse_ic <- function(opp_number, funding_activity) {
  known <- .nih_ic_codes()
  from_num <- stringr::str_match(as.character(opp_number), "^(?:RFA|PAR|PA|NOT)-([A-Z]{2})-[0-9]{2}-")[, 2]
  from_num <- ifelse(from_num %in% known, from_num, NA_character_)
  fa <- toupper(trimws(as.character(funding_activity)))
  fa <- ifelse(fa %in% known, fa, NA_character_)
  dplyr::coalesce(from_num, fa)
}

# Pool rule: open (posted or forecasted), not past as_of, reaches a higher-ed applicant type; one row per opp_id.
# A row whose only applicant type is UNMAPPED stays in the pool with elig "" (eligibility unknown); the token is never kept.
# source_date: max of the fetched_on column when present, else the source_date argument (default as_of).
# Unusual-case flags from the full notice text and the structured cost_sharing column. One named list per input row;
# a key is present only when known: "yes" (the text names it) or "no" (cost_share only, from the structured value).
# These say "the notice mentions X", never "X is required". Anything not stated stays absent (shown as unknown).
parse_flags <- function(summary, eligibility, cost_sharing) {
  n <- length(summary)
  txt <- paste(ifelse(is.na(summary), "", summary), ifelse(is.na(eligibility), "", eligibility))
  has <- function(pat, ic = TRUE) stringr::str_detect(txt, if (ic) stringr::regex(pat, ignore_case = TRUE) else pat)
  hit <- list(
    loi = has("letters? of intent") | has("\\bLOI\\b", FALSE),
    foreign = has("foreign (components?|organizations?|institutions?|entities|applicants?)(?:(?!\\bnot\\b)[^.;]){0,120}\\b(are|is) (allowed|permitted|eligible)|(must|will|should) include (a )?foreign components?"),
    subaward = has("sub-?awards?|subcontract"),
    multi_pi = has("multi-?pi\\b|multiple (principal investigators|pis?\\b|program directors)"),
    ind_ide = has("\\b(IND|IDE)\\b", FALSE) | has("investigational (new drug|device exemption)"),
    data_sharing = has("data (management and )?sharing|data management"),
    animals = has("\\banimal (model|stud|research|subject|use|welfare)|vertebrate animals|\\bIACUC\\b"),
    human_subjects = has("human subjects?"))
  cs <- tolower(trimws(ifelse(is.na(cost_sharing), "", as.character(cost_sharing))))
  cs <- rep_len(cs, n)
  lapply(seq_len(n), function(i) {
    out <- list()
    for (k in names(hit)) if (isTRUE(hit[[k]][i])) out[[k]] <- "yes"
    if (cs[i] == "yes") out$cost_share <- "yes" else if (cs[i] == "no") out$cost_share <- "no"
    out
  })
}

build_research_payload <- function(opps, as_of, source_date = as_of) {
  o <- opps
  if ("fetched_on" %in% names(o) && any(!is.na(o$fetched_on))) source_date <- max(as.Date(as.character(o$fetched_on)), na.rm = TRUE)
  codes <- strsplit(ifelse(is.na(o$applicant_types), "", as.character(o$applicant_types)), "|", fixed = TRUE)
  elig <- vapply(codes, function(x) any(x %in% RESEARCH_ELIGIBLE_CODES) || (length(x) > 0 && all(x == "UNMAPPED")), logical(1))
  elig_txt <- vapply(codes, function(x) paste(setdiff(x, "UNMAPPED"), collapse = "|"), character(1))
  o$applicant_types <- elig_txt
  close <- as.Date(as.character(o$close_date))
  keep <- o$status %in% c("posted", "forecasted") & elig & (is.na(close) | close >= as_of)
  keep[keep] <- !duplicated(o$opp_id[keep])
  o <- o[keep, , drop = FALSE]
  close <- close[keep]
  if (nrow(o) == 0) return(list(as_of = format(as_of), source_date = format(source_date), n = 0L, rows = list()))
  num <- function(x) suppressWarnings(as.numeric(x))
  amt <- function(x) { v <- num(x); ifelse(is.na(v) | v == 0, NA_real_, v) }  # 0 means "not given", as in the NC pipeline
  trial <- parse_trial_status(o$title)
  mech <- parse_mechanism(o$title)
  ic <- parse_ic(o$opp_number, rep(NA_character_, nrow(o)))
  txt <- paste(o$title, o$summary)
  col <- function(nm) if (nm %in% names(o)) as.character(o[[nm]]) else rep(NA_character_, nrow(o))
  flags <- parse_flags(col("summary"), col("eligibility_text"), col("cost_sharing"))
  post <- suppressWarnings(as.Date(col("post_date")))
  rows <- lapply(seq_len(nrow(o)), function(i) list(
    id = as.character(o$opp_id[i]), num = as.character(o$opp_number[i]), title = as.character(o$title[i]),
    agency = as.character(o$agency[i]), status = as.character(o$status[i]),
    close = if (is.na(close[i])) NA_character_ else format(close[i]),
    floor = amt(o$award_floor[i]), ceil = amt(o$award_ceiling[i]),
    mech = mech[i], trial = trial[i], hs = parse_hs_flag(txt[i], trial[i]),
    ic = ic[i],
    flags = if (length(flags[[i]])) flags[[i]] else structure(list(), names = character(0)),
    post = if (is.na(post[i])) NA_character_ else format(post[i]),
    elig = as.character(o$applicant_types[i]), url = as.character(o$url[i]),
    sum = substr(as.character(o$summary[i]), 1, RESEARCH_SUM_MAX)))
  list(as_of = format(as_of), source_date = format(source_date), n = length(rows), rows = rows)
}

# ---- Foundation list (data/manual/foundations.csv -> research_foundations.json) ----------------------------
# Every row must carry its own source page and the date a person last read it there; a row without either is an
# error, never displayed. career_stage and award_note may be empty. Returns character(): one message per problem.
FOUNDATION_COLS <- c("id", "name", "focus", "career_stage", "award_note", "url", "verified_on")
validate_foundations <- function(df, as_of) {
  err <- character()
  miss <- setdiff(FOUNDATION_COLS, names(df))
  if (length(miss)) return(paste("missing column:", miss))
  blank <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))
  for (col in c("id", "name", "focus", "url", "verified_on")) {
    b <- which(blank(df[[col]]))
    if (length(b)) err <- c(err, sprintf("row %d: %s is empty", b, col))
  }
  u <- which(!blank(df$url) & !grepl("^https://", df$url))
  if (length(u)) err <- c(err, sprintf("row %d: url must start with https://", u))
  v <- trimws(as.character(df$verified_on))
  d <- suppressWarnings(as.Date(ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", v), v, NA_character_), format = "%Y-%m-%d"))  # strict, as in app/check_foundations.py
  bd <- which(!blank(df$verified_on) & is.na(d))
  if (length(bd)) err <- c(err, sprintf("row %d: verified_on is not a YYYY-MM-DD date", bd))
  fut <- which(!is.na(d) & d > as_of)
  if (length(fut)) err <- c(err, sprintf("row %d: verified_on is after %s", fut, format(as_of)))
  dup <- which(duplicated(df$id) & !blank(df$id))
  if (length(dup)) err <- c(err, sprintf("row %d: duplicate id %s", dup, df$id[dup]))
  err
}

build_foundations_payload <- function(df, as_of) {
  nz <- function(x) { x <- as.character(x); ifelse(is.na(x) | !nzchar(trimws(x)), NA_character_, trimws(x)) }
  rows <- lapply(seq_len(nrow(df)), function(i) list(id = as.character(df$id[i]), name = as.character(df$name[i]), focus = as.character(df$focus[i]),
    career = nz(df$career_stage[i]), note = nz(df$award_note[i]), url = as.character(df$url[i]), verified = as.character(df$verified_on[i])))
  list(as_of = format(as_of), n = length(rows), rows = rows)
}

# helpers_research.R: parsers and the pool rule for the researcher tab (research.json).
# Pure functions; no file writes. Used by 14_build_research_payload.R and tests/test_research.R.

RESEARCH_ELIGIBLE_CODES <- c("06", "12", "13", "20", "22", "23", "25", "99")  # higher-ed and nonprofit applicant types
RESEARCH_SUM_MAX <- 1200L

# Activity code (R01, U24, R43, SBIR...) from an NIH title; NA when none.
parse_mechanism <- function(title) {
  title <- as.character(title)
  in_paren <- vapply(stringr::str_match_all(title, "[(]([^)]*)[)]"), function(m) {
    hit <- stringr::str_match(m[, 2], "^(?:Parent |Collaborative )?([A-Z][0-9]{2}|[A-Z]{2}[0-9]{1,2}|SBIR|STTR)")[, 2]
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
build_research_payload <- function(opps, as_of) {
  o <- opps
  codes <- strsplit(ifelse(is.na(o$applicant_types), "", as.character(o$applicant_types)), "|", fixed = TRUE)
  elig <- vapply(codes, function(x) any(x %in% RESEARCH_ELIGIBLE_CODES), logical(1))
  close <- as.Date(as.character(o$close_date))
  keep <- o$status %in% c("posted", "forecasted") & elig & (is.na(close) | close >= as_of)
  keep[keep] <- !duplicated(o$opp_id[keep])
  o <- o[keep, , drop = FALSE]
  close <- close[keep]
  if (nrow(o) == 0) return(list(as_of = format(as_of), n = 0L, rows = list()))
  num <- function(x) suppressWarnings(as.numeric(x))
  trial <- parse_trial_status(o$title)
  mech <- parse_mechanism(o$title)
  ic <- parse_ic(o$opp_number, rep(NA_character_, nrow(o)))
  txt <- paste(o$title, o$summary)
  rows <- lapply(seq_len(nrow(o)), function(i) list(
    id = as.character(o$opp_id[i]), num = as.character(o$opp_number[i]), title = as.character(o$title[i]),
    agency = as.character(o$agency[i]), status = as.character(o$status[i]),
    close = if (is.na(close[i])) NA_character_ else format(close[i]),
    floor = num(o$award_floor[i]), ceil = num(o$award_ceiling[i]),
    mech = mech[i], trial = trial[i], hs = parse_hs_flag(txt[i], trial[i]),
    ic = ic[i],
    elig = as.character(o$applicant_types[i]), url = as.character(o$url[i]),
    sum = substr(as.character(o$summary[i]), 1, RESEARCH_SUM_MAX)))
  list(as_of = format(as_of), n = length(rows), rows = rows)
}

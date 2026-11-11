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

.nih_ic_table <- function() readr::read_csv(here::here("data", "manual", "nih_ic_codes.csv"), col_types = "cc", show_col_types = FALSE)
.nih_ic_codes <- function() .nih_ic_table()$ic

# Institute a notice's summary names, as its two-letter code; NA when it names none or cannot be told. Two rules, in order:
# (1) an acronym in parentheses after Institute, Center, Library or Office ("the National Cancer Institute (NCI) solicits");
# (2) the one acronym in the first sentence ("The NIDCD is committed to"). A first sentence naming two institutes is not guessed.
# Case-sensitive, whole-word, and only the acronyms in nih_ic_codes.csv. On the 224 pool rows whose institute is known from the
# opportunity number, these rules agreed on 123 of the 124 they answered (2026-11-10).
.ic_from_summary <- function(summary, tbl) {
  s <- as.character(summary)
  s[is.na(s)] <- ""
  alt <- paste(tbl$name, collapse = "|")
  paren <- stringr::str_match(s, paste0("(Institute|Center|Library|Office)[^()]{0,80}[(](", alt, ")[)]"))[, 3]
  first <- stringr::str_extract(s, "^[^.]{0,400}")
  one <- vapply(stringr::str_extract_all(first, paste0("\\b(", alt, ")\\b")), function(h) {
    u <- unique(h)
    if (length(u) == 1) u else NA_character_
  }, character(1))
  tbl$ic[match(dplyr::coalesce(paren, one), tbl$name)]
}

# Two-letter NIH institute code: from RFA-AG-26-020 style numbers, else a funding_activity value that is a known IC code,
# else (when a summary is given) the institute the summary names. Pass the summary for NIH rows only.
parse_ic <- function(opp_number, funding_activity, summary = NULL) {
  tbl <- .nih_ic_table()
  known <- tbl$ic
  from_num <- stringr::str_match(as.character(opp_number), "^(?:RFA|PAR|PA|NOT)-([A-Z]{2})-[0-9]{2}-")[, 2]
  from_num <- ifelse(from_num %in% known, from_num, NA_character_)
  fa <- toupper(trimws(as.character(funding_activity)))
  fa <- ifelse(fa %in% known, fa, NA_character_)
  out <- dplyr::coalesce(from_num, fa)
  if (!is.null(summary)) out <- dplyr::coalesce(out, .ic_from_summary(rep_len(summary, length(out)), tbl))
  out
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

# Display text: numeric (&#8211;, &#x2019;) and the common named HTML entities become characters; zero-width characters
# drop out, no-break and narrow spaces become spaces. Two passes, as the extract sometimes doubles &amp;. Same intent as
# clean_text() in helpers_rank.R, kept here so this file stands alone.
decode_entities <- function(x) {
  x <- as.character(x)
  named <- c("&lt;" = "<", "&gt;" = ">", "&quot;" = "\"", "&apos;" = "'", "&nbsp;" = " ",
             "&ndash;" = "–", "&mdash;" = "—", "&lsquo;" = "‘", "&rsquo;" = "’", "&sbquo;" = "‚",
             "&ldquo;" = "“", "&rdquo;" = "”", "&bdquo;" = "„", "&hellip;" = "…", "&bull;" = "•",
             "&middot;" = "·", "&sect;" = "§", "&para;" = "¶", "&trade;" = "™", "&copy;" = "©",
             "&reg;" = "®", "&deg;" = "°", "&plusmn;" = "±", "&times;" = "×", "&micro;" = "µ",
             "&euro;" = "€", "&laquo;" = "«", "&raquo;" = "»", "&frac12;" = "½",
             "&eacute;" = "é", "&egrave;" = "è", "&aacute;" = "á", "&iacute;" = "í", "&oacute;" = "ó",
             "&uacute;" = "ú", "&ntilde;" = "ñ", "&ccedil;" = "ç", "&uuml;" = "ü", "&ouml;" = "ö",
             "&auml;" = "ä", "&szlig;" = "ß")
  one <- function(s) {
    if (is.na(s)) return(s)
    s <- gsub("&amp;", "&", s, fixed = TRUE)
    for (e in unique(regmatches(s, gregexpr("&#(?:[0-9]+|[xX][0-9a-fA-F]+);", s, perl = TRUE))[[1]])) {
      body <- substr(e, 3, nchar(e) - 1)
      cp <- if (grepl("^[xX]", body)) strtoi(substring(body, 2), 16L) else strtoi(body, 10L)
      r <- if (is.na(cp) || cp < 1L || cp > 1114111L) e else if (cp %in% c(8203L, 65279L)) "" else if (cp %in% c(160L, 8239L)) " " else intToUtf8(cp)
      s <- gsub(e, r, s, fixed = TRUE)
    }
    for (e in names(named)) s <- gsub(e, named[[e]], s, fixed = TRUE)
    s
  }
  vapply(x, function(s) one(one(s)), character(1), USE.NAMES = FALSE) |> trimws() |> gsub(pattern = "[ \t\r\n]+", replacement = " ")
}

# Grants.gov fetchOpportunity response (parsed JSON) -> post date (YYYY-MM-DD), cost sharing ("Yes"/"No") and eligibility text
# (applicantEligibilityDesc, entities decoded), NA when absent or empty.
# A posted opportunity keeps these in data$synopsis, a forecast in data$forecast.
parse_grantsgov_detail <- function(x) {
  d <- x$data
  blk <- if (length(d$synopsis)) d$synopsis else d$forecast
  ps <- as.character(blk$postingDateStr)
  cs <- blk$costSharing
  el <- as.character(blk$applicantEligibilityDesc)
  el <- if (length(el) == 1 && !is.na(el) && nzchar(trimws(el))) decode_entities(el) else NA_character_
  list(post_date = if (length(ps) == 1 && !is.na(ps) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", ps)) substr(ps, 1, 10) else NA_character_,
       cost_sharing = if (length(cs) == 1 && is.logical(cs) && !is.na(cs)) if (cs) "Yes" else "No" else NA_character_,
       eligibility_text = el)
}

grantsgov_url <- function(opp_id) paste0("https://www.grants.gov/search-results-detail/", opp_id)

# Ids in the pool that the Grants.gov table (opportunities.csv) does not hold, once each, in pool order.
unmatched_opp_ids <- function(pool, gg) {
  ids <- unique(as.character(pool$opp_id))
  if (is.null(gg) || !nrow(gg)) ids else ids[!ids %in% as.character(gg$opp_id)]
}

# Append looked-up rows (opp_id, url, post_date, cost_sharing, eligibility_text) to the Grants.gov table for ids it lacks; its own rows win.
add_grantsgov_lookup <- function(gg, lookup) {
  if (is.null(lookup) || !nrow(lookup)) return(gg)
  lookup <- lookup[!as.character(lookup$opp_id) %in% as.character(gg$opp_id), , drop = FALSE]
  if (!nrow(lookup)) return(gg)
  dplyr::bind_rows(gg, lookup)
}

# The Simpler.Grants.gov pull has no post date, cost sharing, eligibility text or grants.gov link. For rows that also
# appear in the Grants.gov table (matched on opp_id), take those four fields from it. Rows are never added or dropped;
# a row with no match keeps its Simpler link and leaves the other three as NA.
merge_grantsgov_fields <- function(opps, gg) {
  if (is.null(gg) || !nrow(gg)) return(opps)
  idx <- match(as.character(opps$opp_id), as.character(gg$opp_id))
  hit <- !is.na(idx)
  for (nm in c("post_date", "cost_sharing", "eligibility_text")) {
    if (!nm %in% names(gg)) next
    v <- rep(NA_character_, nrow(opps))
    if (nm %in% names(opps)) v <- as.character(opps[[nm]])
    v[hit] <- as.character(gg[[nm]][idx[hit]])
    opps[[nm]] <- v
  }
  if ("url" %in% names(gg)) {
    u <- as.character(opps$url)
    gu <- as.character(gg$url[idx[hit]])
    u[hit] <- ifelse(is.na(gu) | !nzchar(gu), u[hit], gu)
    opps$url <- u
  }
  opps
}

# Keep research.json under max_bytes: when over, cut every summary to a common length, stepping down 100 characters from
# RESEARCH_SUM_MAX to RESEARCH_SUM_FLOOR, until it fits. Rows and all other fields stay; stops if the floor still does not fit.
fit_research_payload <- function(p, max_bytes, floor = RESEARCH_SUM_FLOOR) {
  size <- function(x) nchar(as.character(jsonlite::toJSON(x, auto_unbox = TRUE, na = "null")), type = "bytes")
  if (size(p) <= max_bytes) return(p)
  for (cap in unique(c(seq(RESEARCH_SUM_MAX - 100L, floor, by = -100L), floor))) {
    q <- p
    q$rows <- lapply(p$rows, function(r) { r$sum <- substr(r$sum, 1, cap); r })
    if (size(q) <= max_bytes) return(q)
  }
  stop("research.json is still ", size(q), " bytes with summaries cut to ", floor, " characters; budget is ", max_bytes, call. = FALSE)
}

build_research_payload <- function(opps, as_of, source_date = as_of) {
  o <- opps
  for (nm in intersect(c("title", "agency", "summary"), names(o))) o[[nm]] <- decode_entities(o[[nm]])
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
  is_nih <- grepl("National Institutes of Health|^NIH", as.character(o$agency)) | (if ("agency_code" %in% names(o)) grepl("^HHS-NIH", as.character(o$agency_code)) else FALSE)
  ic <- parse_ic(o$opp_number, rep(NA_character_, nrow(o)), ifelse(is_nih, as.character(o$summary), NA_character_))
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


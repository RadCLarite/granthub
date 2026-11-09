# 01_load_clean.R — read the Grants.gov export, clean it, derive
# weight-independent attributes, and check the result against the verified facts.
# Produces `grants` (one row per opportunity). Requires 00_config.R.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(purrr); library(tibble)
})

# ---- Helpers (kept from the original notebook) --------------------------------

is_unset <- function(x) {
  is.null(x) || length(x) == 0L || all(is.na(x))
}

parse_logical_safe <- function(x) {
  y <- str_to_lower(str_squish(as.character(x)))
  out <- rep(NA, length(y))
  out[y %in% c("true", "t", "yes", "y", "1")] <- TRUE
  out[y %in% c("false", "f", "no", "n", "0")] <- FALSE
  out
}

safe_false <- function(x) {
  dplyr::coalesce(parse_logical_safe(x), FALSE)
}

get_cached <- function(path, fetch_fn) {
  if (file.exists(path)) {
    cached <- tryCatch(readRDS(path), error = function(e) {
      message("Cached file unreadable; refreshing: ", path)
      NULL
    })
    if (!is.null(cached)) return(cached)
  }
  result <- tryCatch(fetch_fn(), error = function(e) {
    message("Fetch failed: ", conditionMessage(e))
    NULL
  })
  if (!is.null(result)) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    saveRDS(result, path)
    # Access date recorded beside every cached download.
    writeLines(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), paste0(path, ".accessed"))
  }
  result
}

parse_date_safe <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "NA", "N/A", "NULL", "null", "NaN")] <- NA_character_
  x <- sub("T.*$", "", x, perl = TRUE)
  x <- sub(" .*$", "", x, perl = TRUE)
  result <- suppressWarnings(as.Date(x))
  for (fmt in c("%m/%d/%Y", "%m/%d/%y", "%Y/%m/%d", "%d/%m/%Y")) {
    miss <- is.na(result) & !is.na(x)
    if (!any(miss)) break
    result[miss] <- suppressWarnings(as.Date(x[miss], format = fmt))
  }
  result
}

# Sentinels such as 2099-01-01 are retained in the raw columns (suffix _raw) but
# excluded from the analytical date fields.
clean_date_outliers <- function(x, min_date = DATE_MIN_VALID, max_date = DATE_MAX_VALID) {
  x <- as.Date(x)
  x[x < min_date | x > max_date] <- as.Date(NA)
  x
}

parse_numeric_safe <- function(x) {
  suppressWarnings(as.numeric(str_replace_all(as.character(x), "[$,]", "")))
}

strip_html <- function(x) {
  x <- str_replace_all(coalesce(x, ""), "<[^>]+>", " ")
  x <- str_replace_all(x, c("&nbsp;" = " ", "&amp;" = "&", "&lt;" = "<", "&gt;" = ">",
                            "&quot;" = "\"", "&#39;" = "'", "&rsquo;" = "'",
                            "&ldquo;" = "\"", "&rdquo;" = "\"", "&ndash;" = "-",
                            "&mdash;" = "-"))
  str_squish(x)
}

split_semicolon <- function(x) {
  map(str_split(coalesce(x, ""), ";"), ~ str_squish(.x[nzchar(str_squish(.x))]))
}

# ---- Load ----------------------------------------------------------------------

load_grants_raw <- function(path = GRANTS_CSV) {
  if (!file.exists(path)) stop("Grants file not found: ", path)
  # Every column read as text. Type guessing from the first 1,000 rows misreads
  # forecasted_close_date_description as logical and drops 151 values.
  readr::read_csv(path, col_types = cols(.default = col_character()),
                  na = c("", "NA", "N/A", "NULL"), show_col_types = FALSE) |>
    janitor::clean_names()
}

# ---- Clean and derive ----------------------------------------------------------

clean_grants <- function(raw, ref_date = REF_DATE_DEFAULT) {
  date_cols <- c("post_date", "close_date", "archive_date", "forecasted_post_date",
                 "forecasted_close_date", "forecasted_award_date",
                 "forecasted_project_start_date")
  num_cols  <- c("award_floor", "award_ceiling", "estimated_total_program_funding",
                 "expected_number_of_awards")

  parsed <- raw |>
    mutate(across(all_of(date_cols), parse_date_safe, .names = "{.col}_raw"),
           across(all_of(num_cols), parse_numeric_safe))

  outlier_flag <- rowSums(sapply(paste0(date_cols, "_raw"), function(nm) {
    v <- parsed[[nm]]
    !is.na(v) & (v < DATE_MIN_VALID | v > DATE_MAX_VALID)
  })) > 0

  research_rx   <- regex(paste(RESEARCH_PATTERNS, collapse = "|"), ignore_case = TRUE)
  restricted_rx <- regex(paste(RESTRICTED_PATTERNS, collapse = "|"), ignore_case = TRUE)

  parsed |>
    mutate(
      across(all_of(paste0(date_cols, "_raw")), clean_date_outliers,
             .names = "{sub('_raw$', '', .col)}"),
      date_outlier_flag = outlier_flag,

      # Booleans already present in this export (the original notebook overwrote
      # is_cost_sharing with FALSE; that bug is fixed by reading it directly).
      is_forecast     = safe_false(is_forecast),
      is_cost_sharing = safe_false(is_cost_sharing),

      status_group = if_else(is_forecast | opportunity_status == "forecasted",
                             "Forecasted", "Posted"),

      summary_text = strip_html(summary_description),
      eligibility_text = strip_html(applicant_eligibility_description),

      applicant_type_list = split_semicolon(applicant_types),
      n_applicant_types   = lengths(applicant_type_list),
      state_eligible      = map_lgl(applicant_type_list, ~ STATE_ELIGIBLE_TOKEN %in% .x),
      state_only          = state_eligible & n_applicant_types == 1L,

      instrument_list = split_semicolon(funding_instruments),
      is_coop_agreement = map_lgl(instrument_list, ~ "cooperative_agreement" %in% .x),

      cfda_list = split_semicolon(opportunity_assistance_listings),
      cfda_numbers = map(cfda_list, ~ str_extract(.x, "^[0-9]+\\.[0-9A-Za-z]+")),

      is_nih = str_detect(coalesce(agency_code, ""), NIH_AGENCY_CODE_REGEX),
      is_va  = str_detect(coalesce(agency_code, ""), VA_AGENCY_CODE_REGEX),

      screen_text = str_to_lower(str_c(
        coalesce(opportunity_title, ""), summary_text, eligibility_text,
        coalesce(category, ""), coalesce(category_explanation, ""), sep = " | ")),
      is_research_mechanism     = str_detect(screen_text, research_rx),
      is_restricted_competition = str_detect(screen_text, restricted_rx),

      match_text = str_to_lower(str_c(
        coalesce(opportunity_title, ""), summary_text, eligibility_text,
        coalesce(close_date_description, ""), coalesce(funding_category_description, ""),
        coalesce(category_explanation, ""), coalesce(additional_info_url_description, ""),
        sep = " | ")),
      states_match_pct = str_detect(match_text, MATCH_PCT_PATTERN),
      match_pct = suppressWarnings(as.numeric(str_match(
        str_extract(match_text, MATCH_PCT_PATTERN), "(\\d{1,3}(?:\\.\\d+)?) ?(?:%|percent)")[, 2])),

      # Implied per-award: the national pot divided by expected awards. The pot
      # itself is never presented as money NC could receive.
      implied_award_usd = if_else(
        !is.na(estimated_total_program_funding) & !is.na(expected_number_of_awards) &
          expected_number_of_awards > 0,
        estimated_total_program_funding / expected_number_of_awards, NA_real_),
      award_ceiling_clean = if_else(award_ceiling > 1, award_ceiling, NA_real_),
      award_basis = case_when(
        !is.na(implied_award_usd)   ~ "total_over_count",
        !is.na(award_ceiling_clean) ~ "ceiling",
        TRUE                        ~ NA_character_),
      award_estimate_usd = coalesce(implied_award_usd, award_ceiling_clean),

      application_window_days = as.numeric(close_date - post_date),
      days_to_close = as.numeric(close_date - ref_date)
    )
}

# ---- Verified facts (build spec section 3) --------------------------------------

compute_facts <- function(g) {
  cutoff <- FACT_REF_DATE + FACT_RUNWAY_DAYS
  open_state <- g |> filter(status_group == "Posted", state_eligible,
                            !is.na(close_date), close_date >= cutoff)
  state <- g |> filter(state_eligible)
  win <- g |> filter(status_group == "Posted", !is.na(application_window_days),
                     application_window_days >= 0,
                     application_window_days <= WINDOW_MAX_DAYS) |>
    pull(application_window_days)
  both <- g |> filter(!is.na(implied_award_usd))
  ratio <- both |> filter(!is.na(award_ceiling_clean)) |>
    mutate(r = implied_award_usd / award_ceiling_clean) |> pull(r)
  instr <- table(unlist(g$instrument_list))
  cats  <- table(g$category)
  fc <- g |> filter(status_group == "Forecasted", state_eligible, !is_nih)
  fc_window <- sum(fc$forecasted_post_date >= FORECAST_WINDOW[1] &
                     fc$forecasted_post_date <= FORECAST_WINDOW[2], na.rm = TRUE)
  closed_recent <- sum(g$close_date < PULL_DATE &
                         g$close_date >= PULL_DATE - MISSED_LOOKBACK_DAYS, na.rm = TRUE)
  pct <- function(x) sprintf("%.1f%%", 100 * x)
  usd <- function(x) paste0("$", format(round(x), big.mark = ",", scientific = FALSE))

  tribble(
    ~fact, ~expected, ~computed,
    "Rows / columns", "1,662 / 40", sprintf("%s / %d", format(nrow(g), big.mark = ","), ncol(load_grants_raw())),
    "Posted / forecasted", "1,103 / 559",
      sprintf("%s / %d", format(sum(g$status_group == "Posted"), big.mark = ","), sum(g$status_group == "Forecasted")),
    "Open, state-eligible, closing on or after 2026-11-14", "296", as.character(nrow(open_state)),
    "Of those, NIH-issued", "272", as.character(sum(open_state$is_nih)),
    "Of those, non-NIH", "24", as.character(sum(!open_state$is_nih)),
    "Rows listing state_governments as eligible", "887", as.character(nrow(state)),
    "Of those, state-government-only", "12", as.character(sum(state$state_only)),
    "Of those, 3 or fewer applicant types", "36", as.character(sum(state$n_applicant_types <= 3)),
    "Applicant-type breadth: rows listing 1 type / 15 types", "630 / 587",
      sprintf("%d / %d", sum(g$n_applicant_types == 1), sum(g$n_applicant_types == 15)),
    "Application window n", "471", as.character(length(win)),
    "Application window median / p25 / p10 (days)", "66 / 33 / 29",
      sprintf("%g / %g / %g", median(win), quantile(win, .25, names = FALSE), quantile(win, .10, names = FALSE)),
    "Windows <= 30 days", "16.3%", pct(mean(win <= WINDOW_CUTOFFS_DAYS[1])),
    "Windows <= 45 days", "35.7%", pct(mean(win <= WINDOW_CUTOFFS_DAYS[2])),
    "is_cost_sharing TRUE", "117", as.character(sum(g$is_cost_sharing)),
    "Rows stating a match percentage anywhere in text", "6", as.character(sum(g$states_match_pct)),
    "Rows with both total funding and award count", "777", as.character(nrow(both)),
    "Implied per-award median", "$750,000", usd(median(both$implied_award_usd)),
    "Implied vs stated ceiling: n / median ratio", "451 / 1.00", sprintf("%d / %.2f", length(ratio), median(ratio)),
    "Instruments: grant / coop / other / contract", "1,070 / 655 / 57 / 30",
      sprintf("%s / %d / %d / %d", format(instr[["grant"]], big.mark = ","), instr[["cooperative_agreement"]],
              instr[["other"]], instr[["procurement_contract"]]),
    "Category: discretionary / other / mandatory / earmark", "1,598 / 29 / 27 / 8",
      sprintf("%s / %d / %d / %d", format(cats[["discretionary"]], big.mark = ","), cats[["other"]],
              cats[["mandatory"]], cats[["earmark"]]),
    "Distinct CFDA entries", "383", as.character(length(unique(unlist(g$cfda_list)))),
    "Forecast rows, state-eligible, non-NIH (posting 2026Q3-2027Q1)", "129 (83)",
      sprintf("%d (%d)", nrow(fc), fc_window),
    "VA-issued opportunities", "3", as.character(sum(g$is_va)),
    "Rows closed in the 60 days before the pull date", "0", as.character(closed_recent)
  ) |>
    mutate(result = if_else(expected == computed, "PASS", "FAIL"))
}

# ---- Run -----------------------------------------------------------------------

grants_raw <- load_grants_raw()
grants     <- clean_grants(grants_raw)

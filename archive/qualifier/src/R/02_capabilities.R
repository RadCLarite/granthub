# 02_capabilities.R — the capability model.
#   1. Load the hand-authored agency capability profiles.
#   2. Extract each opportunity's requirement profile from deterministic signals
#      (structured fields first, then sentence-level regexes on the abstract).
#   3. Build opportunity records in the payload.json shape.
#   4. Run the JavaScript tier rules (src/tool/tiering.js) through V8. The rules
#      exist only in JS; R never re-implements them.
# Requires 00_config.R and 01_load_clean.R. Phase 2 LLM labels, when present,
# are merged in by 03_llm_label.R and take precedence where validated.

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(purrr); library(tibble); library(jsonlite)
})

# ---- 1. Agency capability profiles ---------------------------------------------------

load_capabilities <- function() {
  caps <- readr::read_csv(file.path(DIR_MANUAL, "agency_capabilities.csv"),
                          col_types = readr::cols(.default = "c"))
  bad <- caps |> filter(is.na(source_url) | !nzchar(source_url))
  if (nrow(bad) > 0) stop("Unsourced capability rows: ", paste(bad$agency, bad$capability_id, collapse = ", "))
  stopifnot(all(caps$control_level %in% c("direct", "contracted", "partner", "none")),
            all(caps$capability_id %in% CAPABILITIES))
  caps
}

# ---- 2. Requirement signals ---------------------------------------------------------------

# Sentences that say something is NOT allowed must not trigger a requirement
# ("funds may not be used for construction").
NEGATION_RX <- regex("\\b(not|unallowable|prohibited|ineligible|cannot|excluded|no funds)\\b", ignore_case = TRUE)

sentence_hit <- function(text, pattern) {
  rx <- regex(pattern, ignore_case = TRUE)
  map_lgl(text, function(t) {
    if (is.na(t) || !nzchar(t)) return(FALSE)
    s <- unlist(str_split(t, "(?<=[.;!?])\\s+"))
    any(str_detect(s, rx) & !str_detect(s, NEGATION_RX))
  })
}

REQUIREMENT_PATTERNS <- list(
  subrecipient = "\\bsub-?awards?\\b|\\bsub-?recipients?\\b|\\bsub-?grants?\\b|pass[- ]through|\\bre-?grant",
  evaluation   = "evaluation plan|program evaluation|independent evaluat|rigorous evaluat|evaluate the (program|project|intervention|effectiveness)|outcome evaluation|process evaluation",
  capital      = "\\bconstruction\\b|\\brenovat|acquisition of (real property|land|facilit)|capital (project|improvement)|\\bbuild(ing)? (a |new )?facilit",
  designation  = "governor'?s? (designat|letter|signature|office must)|designated (by the governor|state agency)|single state agency|state[- ]designated entity|chief executive (officer )?of the state|signed by the governor"
)

# Keyword fallback for required capabilities (Phase 2 LLM replaces where validated).
CAPABILITY_PATTERNS <- c(
  clinical_service_delivery = "clinical services|primary care|patient care|health care services|medical services|health centers?\\b",
  behavioral_health_delivery = "behavioral health|mental health (services|treatment|care)|substance use (disorder )?treatment|crisis (services|response|care)|\\b988\\b|psychiatric",
  long_term_care_operation = "nursing home|long[- ]term care|skilled nursing|assisted living|veterans home|state home",
  public_health_surveillance = "surveillance|epidemiolog|case reporting|disease reporting|syndromic",
  data_systems_interoperability = "data systems?|interoperab|health information exchange|electronic health records?|data infrastructure|data linkage|information systems?",
  research_and_rigorous_evaluation = "randomi[sz]ed|rigorous evaluation|evaluation design|quasi-experimental|build(s)? the evidence|evidence base for",
  housing_stock_or_assistance = "\\bhousing\\b|homeless|rental assistance|\\bshelters?\\b",
  transportation_services = "\\btransportation\\b|\\btransit\\b",
  workforce_training_credentialing = "workforce|apprenticeship|credential|recruitment and retention|career pathway",
  emergency_management = "emergency management|hazard mitigation|disaster (response|recovery|preparedness)|emergency (preparedness|response)",
  benefits_eligibility_administration = "eligibility determination|benefits? (administration|enrollment)|\\bsnap\\b|\\bwic\\b|\\btanf\\b|medicaid enrollment",
  laboratory_services = "laborator|specimen|genomic sequencing|testing capacity"
)

DOMAIN_PATTERNS <- c(
  D02 = "opioid|substance use|overdose|naloxone|addiction|harm reduction|\\bsud\\b|\\boud\\b",
  D01 = "behavioral health|mental health|suicide|\\b988\\b|crisis|psychiatric",
  D03 = "maternal|infant|pregnan|prenatal|perinatal|reproductive|family planning|title x|doula|syphilis",
  D05 = "nutrition|food (security|insecurity)|\\bwic\\b|\\bsnap\\b|hunger|breastfeed",
  D04 = "child welfare|foster|kinship|adoption|early childhood|child care|parenting|families",
  D06 = "older adults|aging|disabilit|long[- ]term care|nursing home|veteran|dementia|alzheimer|caregiv",
  D07 = "workforce|rural|telehealth|broadband|primary care|health access|community health worker|underserved",
  D08 = "surveillance|infectious|immuniz|vaccin|laborator|preparedness|emergency|disaster|hazard|hurricane|flood|outbreak"
)

extract_requirements <- function(g) {
  text <- str_c(coalesce(g$opportunity_title, ""), ". ", g$summary_text, " ", g$eligibility_text)
  lower <- str_to_lower(text)

  cap_hits <- map(CAPABILITY_PATTERNS, ~ str_detect(lower, regex(.x)))
  required_caps <- pmap(cap_hits, function(...) names(CAPABILITY_PATTERNS)[c(...)])

  domain_first <- map_chr(lower, function(t) {
    hit <- names(DOMAIN_PATTERNS)[str_detect(t, DOMAIN_PATTERNS)]
    if (length(hit)) hit[1] else NA_character_
  })

  g |>
    mutate(
      match_required           = is_cost_sharing,
      subrecipient_required    = sentence_hit(text, REQUIREMENT_PATTERNS$subrecipient),
      evaluation_required      = sentence_hit(text, REQUIREMENT_PATTERNS$evaluation),
      is_capital_project       = sentence_hit(text, REQUIREMENT_PATTERNS$capital),
      needs_formal_designation = sentence_hit(text, REQUIREMENT_PATTERNS$designation),
      instrument = case_when(
        is_coop_agreement ~ "cooperative_agreement",
        map_lgl(instrument_list, ~ "grant" %in% .x) ~ "grant",
        map_lgl(instrument_list, ~ "procurement_contract" %in% .x) ~ "procurement_contract",
        TRUE ~ "other"),
      instrument_burden = case_when(
        is_coop_agreement & (subrecipient_required | evaluation_required) ~ "high",
        is_coop_agreement | subrecipient_required | evaluation_required  ~ "medium",
        TRUE ~ "low"),
      required_capabilities = pmap(
        list(required_caps, subrecipient_required, is_capital_project),
        function(caps, sub, cap) unique(c(caps,
          if (sub) "subrecipient_network_management",
          if (cap) "capital_construction"))),
      domain = domain_first,
      requirement_source = "rule"
    )
}

# ---- 3. Payload-shaped records --------------------------------------------------------------

day_num <- function(d) as.integer(d)   # days since 1970-01-01

# Which agency views an opportunity appears in. Interim rule until the Phase 2
# LLM alignment judgment exists: VA-issued → DMVA, everything else → DHHS.
audience_for <- function(g) {
  map(g$is_va, function(va) if (va) "DMVA" else "DHHS")
}

build_opportunity_records <- function(g, alignment = NULL) {
  g <- g |> filter(state_eligible)
  close <- if_else(g$status_group == "Forecasted", g$forecasted_close_date, g$close_date)
  post  <- if_else(g$status_group == "Forecasted", g$forecasted_post_date, g$post_date)
  aud <- audience_for(g)
  al <- NULL
  if (!is.null(alignment)) {
    al <- alignment |> select(opportunity_number, agency, emb_pct, emb_best_id, emb_score)
  }
  map(seq_len(nrow(g)), function(i) {
    r <- g[i, ]
    rec <- list(
      id = r$opportunity_id, number = r$opportunity_number, title = r$opportunity_title,
      agency_code = r$agency_code, agency_name = r$agency_name, url = r$url,
      status = tolower(r$status_group), audience = I(aud[[i]]),
      post_day = day_num(post[i]), close_day = day_num(close[i]),
      award_estimate_usd = r$award_estimate_usd, award_basis = r$award_basis,
      implied_award_usd = r$implied_award_usd, ceiling_usd = r$award_ceiling_clean,
      expected_awards = r$expected_number_of_awards,
      instrument = r$instrument, instrument_burden = r$instrument_burden,
      cost_share = r$match_required, match_pct = r$match_pct,
      subrecipient_required = r$subrecipient_required,
      evaluation_required = r$evaluation_required,
      is_capital_project = r$is_capital_project,
      needs_formal_designation = r$needs_formal_designation,
      required_capabilities = I(r$required_capabilities[[1]]),
      domain = r$domain,
      screen = list(is_nih = r$is_nih, is_research_mechanism = r$is_research_mechanism,
                    is_restricted = r$is_restricted_competition),
      provenance = list(cost_share = "csv:is_cost_sharing", requirements = r$requirement_source),
      summary_snippet = str_sub(r$summary_text, 1, 600)
    )
    if (!is.null(al)) {
      a <- al[al$opportunity_number == r$opportunity_number, ]
      rec$alignment <- setNames(map(seq_len(nrow(a)), function(k) list(
        pct = a$emb_pct[k], best_id = a$emb_best_id[k], score = a$emb_score[k], method = "embedding")),
        a$agency)
    }
    rec
  })
}

build_capability_profiles <- function(caps = load_capabilities()) {
  split(caps, caps$agency) |>
    map(function(d) setNames(map(seq_len(nrow(d)), function(i) list(
      control = d$control_level[i], label = d$capability_label[i],
      notes = d$notes[i], source_url = d$source_url[i],
      to_resolve = coalesce(d$to_resolve[i], ""))), d$capability_id))
}

default_settings <- function(agency = AGENCY_DEFAULT) {
  list(
    ref_day = day_num(REF_DATE_DEFAULT), runway_days = RUNWAY_DAYS_DEFAULT,
    match_authority = MATCH_AUTHORITY_DEFAULT, staff_fte = STAFF_FTE_DEFAULT,
    min_award_usd = MIN_AWARD_DEFAULT, include_forecasts = INCLUDE_FORECASTS_DEFAULT,
    show_screened = SHOW_SCREENED_DEFAULT, agency = agency,
    domain_weights = as.list(setNames(rep(DOMAIN_WEIGHT_DEFAULT, length(DOMAINS)), names(DOMAINS))),
    appropriation_usd = APPROPRIATION_THRESHOLD_USD,
    fte_by_burden = as.list(FTE_BY_BURDEN),
    impact_weights = as.list(IMPACT_WEIGHTS_DEFAULT),
    sort_by = SORT_BY_DEFAULT
  )
}

# ---- 4. Run the JS rules through V8 -------------------------------------------------------------

tiering_js_path <- function() here::here("src", "tool", "tiering.js")

run_tiering_js <- function(opportunities, profiles, settings = default_settings()) {
  ctx <- V8::v8()
  ctx$source(tiering_js_path())
  # Serialized exactly as payload.json will be, so V8 sees what the browser sees.
  to_js <- function(x) toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
  ctx$eval(paste0("var payload = ", to_js(list(opportunities = opportunities,
                                                 capabilities = list(profiles = profiles))), ";"))
  ctx$eval(paste0("var settings = ", to_js(settings), ";"))
  out <- ctx$eval("JSON.stringify(Tiering.runFlat(payload, settings))")
  as_tibble(fromJSON(out))
}

# ---- Standalone run: Phase 1 checkpoint ---------------------------------------------------------
if (sys.nframe() == 0L) {
  here::i_am("src/R/02_capabilities.R")
  source(here::here("src", "R", "00_config.R"))
  source(here::here("src", "R", "01_load_clean.R"))
  set.seed(SEED)
  reqs <- extract_requirements(grants)
  alignment_path <- file.path(DIR_PROCESSED, "alignment.rds")
  alignment <- if (file.exists(alignment_path)) readRDS(alignment_path) else NULL
  opps <- build_opportunity_records(reqs, alignment)
  profiles <- build_capability_profiles()
  res <- run_tiering_js(opps, profiles) |>
    left_join(select(grants, opportunity_number, opportunity_title, agency_code), by = "opportunity_number")
  saveRDS(list(requirements = reqs, tiers_default = res), file.path(DIR_PROCESSED, "capabilities_phase1.rds"))

  options(width = 200)
  cat("\nPlacement at default settings (DHHS):\n"); print(count(res, placement, tier))
  cat("\nRequirement signal rates among piled opportunities:\n")
  piled <- reqs |> semi_join(filter(res, placement == "pile"), by = "opportunity_number")
  print(summarise(piled, n = n(), cost_share = sum(match_required), subrecipient = sum(subrecipient_required),
                  evaluation = sum(evaluation_required), capital = sum(is_capital_project),
                  designation = sum(needs_formal_designation), no_caps = sum(lengths(required_capabilities) == 0),
                  no_domain = sum(is.na(domain))))
  cat("\n10 sample tier_reason strings:\n")
  samp <- res |> filter(placement == "pile") |> group_by(tier) |> slice_sample(n = 4) |> ungroup() |> slice_head(n = 10)
  for (i in seq_len(nrow(samp))) cat(sprintf("\n[Tier %d] %s (%s)\n   %s\n", samp$tier[i],
    str_sub(samp$opportunity_title[i], 1, 90), samp$opportunity_number[i], samp$tier_reason[i]))
}

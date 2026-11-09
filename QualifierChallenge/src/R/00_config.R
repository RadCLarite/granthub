# 00_config.R — every path, threshold, and default lives here. Sourced first by
# every script and by the notebook. Tool defaults are exported into payload.json,
# so the JavaScript never holds its own copy of a number.

suppressPackageStartupMessages(library(here))

# UTF-8 everywhere: text is hashed for the LLM cache, so a locale that mangles
# characters would silently change cache keys between machines.
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))

# =============================================================================
# USER-TUNABLE THRESHOLDS — change these freely. Each is also editable live in
# the tool's "Assumptions" panel; the values here are the defaults it opens with.
# =============================================================================

# Tier 3 fires when cost share is present AND implied award is at or above this.
# PLACEHOLDER ASSUMPTION: no published NC rule sets this line. Revisit.
APPROPRIATION_THRESHOLD_USD <- 1e6

# FTE a new application is assumed to need, by instrument burden. If the writer's
# available FTE is below this, the opportunity moves to Tier 2 ("needs new staff").
FTE_BY_BURDEN <- c(low = 0.25, medium = 0.5, high = 1)

# An opportunity is shown under an agency when its alignment percentile for that
# agency is at or above this cutoff (issuing-agency matches are always shown).
ALIGNMENT_AUDIENCE_PCT <- 0.80

# Plan rows about how the agency runs itself (HR, invoices, buildings, onboarding)
# are marked alignable = FALSE in data/manual/*_priorities.csv. TRUE leaves them
# out of alignment scoring; set FALSE to score against every plan row.
ALIGN_EXCLUDE_INTERNAL_OPS <- TRUE

# Research-screened opportunities above this alignment percentile are flagged
# "check this" instead of being silently screened out.
ALIGNMENT_RESCUE_PCT <- 0.90

# =============================================================================
# Tool controls: defaults and ranges
# =============================================================================
REF_DATE_DEFAULT          <- as.Date("2026-09-30")
RUNWAY_DAYS_DEFAULT       <- 45L
RUNWAY_DAYS_RANGE         <- c(0L, 180L)
MATCH_AUTHORITY_LEVELS    <- c("no", "with_approval", "yes")
MATCH_AUTHORITY_DEFAULT   <- "with_approval"
STAFF_FTE_DEFAULT         <- 1
STAFF_FTE_RANGE           <- c(0, 5)
STAFF_FTE_STEP            <- 0.25
MIN_AWARD_DEFAULT         <- 250000
MIN_AWARD_RANGE           <- c(0, 5e6)
MIN_AWARD_STEP            <- 25000
INCLUDE_FORECASTS_DEFAULT <- FALSE
AGENCIES                  <- c("DHHS", "DMVA")
AGENCY_DEFAULT            <- "DHHS"
DOMAIN_WEIGHT_DEFAULT     <- 1
SHOW_SCREENED_DEFAULT     <- TRUE    # research awards shown as Tier 4 (partner-led)

# Impact score: orders opportunities within each pile; it never changes a tier.
# Weights 0-3; the tool lets the writer change them and pick the most important part.
IMPACT_WEIGHTS_DEFAULT <- c(alignment = 1, reach = 1, depth = 1, award = 1, priority = 1)
SORT_BY_DEFAULT        <- "impact"   # or "deadline"

# Program domains (approved 2026-09-29; definitions in src/docs/domain_taxonomy.md)
DOMAINS <- c(
  D01 = "Behavioral health and crisis",
  D02 = "Substance use and overdose",
  D03 = "Maternal, infant and reproductive health",
  D04 = "Child and family well-being",
  D05 = "Food and nutrition security",
  D06 = "Aging, disability and long-term care",
  D07 = "Health access and workforce",
  D08 = "Public health preparedness, infectious disease and disaster"
)

# Target populations for the reach-vs-intensity view. The labeler picks one per
# opportunity; each maps to a sourced North Carolina count in 05_export_tool_data.R.
POPULATIONS <- c(
  all_residents          = "All NC residents",
  children               = "Children under 18",
  older_adults           = "Adults 65 and older",
  people_with_disability = "People with a disability",
  people_in_poverty      = "People below the poverty line",
  uninsured              = "People without health insurance",
  snap_households        = "Households receiving SNAP",
  recent_births          = "Women who gave birth in the past year",
  veterans               = "Veterans",
  adults_mental_distress = "Adults with frequent mental distress",
  people_with_sud        = "People with a substance use disorder",
  shortage_area_residents = "Residents of health professional shortage areas",
  hazard_exposed         = "Residents of high-hazard-risk counties",
  system_level           = "System or infrastructure (no direct beneficiaries)"
)

CAPABILITIES <- c(
  "clinical_service_delivery", "behavioral_health_delivery", "long_term_care_operation",
  "public_health_surveillance", "data_systems_interoperability",
  "research_and_rigorous_evaluation", "housing_stock_or_assistance",
  "transportation_services", "workforce_training_credentialing", "emergency_management",
  "benefits_eligibility_administration", "capital_construction", "laboratory_services",
  "subrecipient_network_management"
)

# =============================================================================
# Paths — resolved from the project root, never from the working directory
# =============================================================================
DIR_RAW          <- here("data", "raw")
DIR_RAW_GRANTS   <- here("data", "raw", "grants")
DIR_RAW_NOFO     <- here("data", "raw", "grants", "nofo")
DIR_RAW_PLANS    <- here("data", "raw", "strategic_plans")
DIR_MANUAL       <- here("data", "manual")
DIR_CACHE_API    <- here("data", "cache", "api")
DIR_CACHE_GRANTS <- here("data", "cache", "api", "grantsgov")
DIR_CACHE_GEO    <- here("data", "cache", "boundaries")
DIR_CACHE_LLM    <- here("data", "cache", "llm")
DIR_PROCESSED    <- here("data", "processed")
DIR_OUTS         <- here("outs")
DIR_OUTS_TABLES  <- here("outs", "tables")
GRANTS_CSV       <- file.path(DIR_RAW_GRANTS, "grants-search-202608182008.csv")
PAYLOAD_JSON     <- file.path(DIR_PROCESSED, "payload.json")
TOOL_HTML_OUT    <- file.path(DIR_OUTS, "grant-triage-tool.html")

# =============================================================================
# Snapshot and date cleaning
# =============================================================================
PULL_DATE      <- as.Date("2026-08-18")   # from export filename 202608182008
DATE_MIN_VALID <- as.Date("2000-01-01")
DATE_MAX_VALID <- as.Date("2035-12-31")   # drops the 2099-01-01 sentinel

# =============================================================================
# Screening signals
# =============================================================================
STATE_ELIGIBLE_TOKEN  <- "state_governments"
NIH_AGENCY_CODE_REGEX <- "^HHS-NIH"
VA_AGENCY_CODE_REGEX  <- "^VA-"

RESEARCH_PATTERNS <- c(
  "investigator initiated", "investigator-initiated", "research project grant",
  "clinical trial", "research grant", "\\br01\\b", "\\br03\\b", "\\br21\\b",
  "\\br34\\b", "\\bu01\\b", "\\bp01\\b", "\\bp20\\b", "\\bp30\\b", "\\bp50\\b",
  "\\bk01\\b", "\\bk08\\b", "\\bk23\\b", "\\bt32\\b", "\\bf31\\b", "\\bf32\\b"
)
RESTRICTED_PATTERNS <- c(
  "only the following applicant", "only the following entit",
  "single source", "sole source", "invited applicant", "not a competitive"
)

# A stated match or cost-share percentage: a percent within 120 characters of
# "match" or "cost share", in either order, within one sentence.
MATCH_PCT_PATTERN <- paste0(
  "(match|cost[- ]shar)[^.]{0,120}\\d{1,3}(\\.\\d+)? ?(%|percent)",
  "|\\d{1,3}(\\.\\d+)? ?(%|percent)[^.]{0,120}(match|cost[- ]shar)"
)

# =============================================================================
# Section 3 fact-check anchors
# =============================================================================
FACT_REF_DATE          <- as.Date("2026-09-30")
FACT_RUNWAY_DAYS       <- 45L                    # → closing on/after 2026-11-14
WINDOW_MAX_DAYS        <- 400L                   # post-to-close windows kept for the distribution
WINDOW_CUTOFFS_DAYS    <- c(30L, 45L)
MISSED_LOOKBACK_DAYS   <- 60L
FORECAST_WINDOW        <- as.Date(c("2026-07-01", "2027-03-31"))  # 2026Q3–2027Q1

# =============================================================================
# Geography
# =============================================================================
NC_FIPS              <- "37"
BOUNDARY_YEAR        <- 2023L
PEER_FIPS            <- c(GA = "13", VA = "51", SC = "45", TN = "47")
BOUNDARY_GEOGRAPHIES <- c("county", "congressional_district", "tract", "place")
GEO_SIMPLIFY_KEEP    <- c(county = 0.05, congressional_district = 0.05,
                          tract = 0.02, place = 0.03)

# =============================================================================
# Plots
# =============================================================================
PLOT_MAX_RUNWAY_DAYS <- 400L
PLOT_AWARD_QUANTILE  <- 0.99

# =============================================================================
# Grants.gov enrichment (free public API, no key)
# =============================================================================
GRANTSGOV_API_BASE     <- "https://api.grants.gov/v1/api"
GRANTSGOV_ATT_BASE     <- "https://apply07.grants.gov/grantsws/rest/opportunity/att/download"
GRANTSGOV_SLEEP_SEC    <- 0.5
NOFO_MAX_BYTES         <- 25 * 1024^2

# =============================================================================
# Local LLM (Ollama, free, runs on this machine)
# =============================================================================
OLLAMA_URL         <- Sys.getenv("OLLAMA_URL", "http://localhost:11434")
LLM_EMBED_MODEL    <- "nomic-embed-text"
LLM_LABEL_MODEL    <- "qwen2.5:14b"
LLM_TEMPERATURE    <- 0
LLM_PROMPT_VERSION <- "v3.1"
LLM_MAX_INPUT_CHARS <- 12000
LLM_NUM_CTX        <- 8192L
LLM_PARALLEL       <- 3L         # concurrent requests; start Ollama with OLLAMA_NUM_PARALLEL=3
LLM_ABSTRACT_CHARS <- 5000L     # abstract text sent to the labeler
LLM_NOFO_HEAD_CHARS <- 2500L    # opening of the full announcement (program description)
LLM_NOFO_KEY_CHARS <- 4000L     # plus sentences that mention match, subawards, evaluation, etc.
# An opportunity appears in an agency's view when the labeler rates alignment at
# least this strong ("strong" or "partial"), or the agency issued it.
AUDIENCE_MIN_LEVEL <- "partial"
EMBED_MAX_CHARS    <- 6000      # nomic-embed-text context is ~2k tokens
EMBED_BATCH_SIZE   <- 32L
SEED               <- 20260930L

# =============================================================================
# Alignment scoring
# =============================================================================
PRIORITY_FILES <- c(DHHS = "dhhs_priorities.csv", DMVA = "dmva_priorities.csv")
BM25_K1 <- 1.2
BM25_B  <- 0.75
BM25_STOPWORDS <- c(
  "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "have",
  "in", "into", "is", "it", "its", "of", "on", "or", "our", "that", "the", "their",
  "this", "to", "we", "will", "with", "which", "who", "all", "other", "such",
  "these", "those", "than", "through", "can", "may", "must", "not", "nc", "north",
  "carolina", "carolinas", "carolinians", "state", "program", "programs")

# =============================================================================
# Build
# =============================================================================
PAYLOAD_SCHEMA_VERSION <- "1.0.0"
TOOL_MAX_BYTES         <- 20 * 1024^2

# =============================================================================
# Secrets — read from .Renviron (gitignored). Empty → ACS degrades to "not available".
# =============================================================================
# R only reads .Renviron from the working directory or home; Quarto runs from src/,
# so load the project-root file explicitly.
if (file.exists(here(".Renviron"))) readRenviron(here(".Renviron"))
CENSUS_API_KEY <- Sys.getenv("CENSUS_API_KEY")

# =============================================================================
# Tool presets and scenario parser
# =============================================================================
PRESETS <- list(
  list(id = "persona", label = "Mid-level writer",
       blurb = "About a month, supervisor must approve match, one FTE, forecasts included",
       settings = list(runway_days = 30L, match_authority = "with_approval", staff_fte = 1,
                       min_award_usd = 250000, include_forecasts = TRUE)),
  list(id = "crunch", label = "Deadline crunch",
       blurb = "Two weeks, no match authority, half an FTE",
       settings = list(runway_days = 14L, match_authority = "no", staff_fte = 0.5,
                       min_award_usd = 100000, include_forecasts = FALSE)),
  list(id = "backed", label = "Division-backed",
       blurb = "90 days, match approved in advance, three FTE",
       settings = list(runway_days = 90L, match_authority = "yes", staff_fte = 3,
                       min_award_usd = 500000, include_forecasts = FALSE)),
  list(id = "planning", label = "Planning ahead",
       blurb = "Include forecasts, 60 days of runway, needs approval for match",
       settings = list(runway_days = 60L, match_authority = "with_approval", staff_fte = 1,
                       min_award_usd = 250000, include_forecasts = TRUE))
)
DEFAULT_PRESET_ID      <- "persona"   # the interview persona the tool opens with
PARSER_DOMAIN_BOOST    <- 3           # weight given to a domain mentioned in the scenario text

# =============================================================================
# County need layers (domain need index = mean percentile rank of its indicators)
# =============================================================================
FEMA_DECLARATIONS_SINCE <- as.Date("2016-01-01")
ACS_YEAR                <- 2023L
OVERDOSE_YEARS          <- 2019:2021   # NCHS model-based drug poisoning death rates, averaged

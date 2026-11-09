# 00_config.R: every path, threshold and default lives here. Sourced first by every
# script and by the notebook. Tool defaults are exported into payload.json, so the
# JavaScript never holds its own copy of a number.
#
# Run every script from the repo root (here() finds the project through granthub.Rproj).

suppressPackageStartupMessages(library(here))

# UTF-8 everywhere: text is hashed for the LLM cache, so a locale that mangles
# characters would silently change cache keys between machines.
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))

# =============================================================================
# FILL IN AT RELEASE
# =============================================================================
PROJECT_TITLE <- "grantHub"
PROJECT_SUB   <- "Solve-A-Thon 2026 Final Quest"

ID_COL     <- "id"                                   # unique key of one item
NAME_COL   <- "title"                                # what the user sees as the item's name
SHOW_FIELDS <- c("agency_id", "close_date", "award_ceiling") # extra columns shown next to each result

REF_DATE   <- as.Date("2026-11-06")  # FROZEN. Part of the fetch cache keys (02b, 02e), fetch extraction and the backtests: never move it, or the daily job would call outside services.
SNAPSHOT_AS_OF_DATE <- as.Date("2026-11-07")  # the as-of date the committed payload.json and facts.csv were built for
TOP_N      <- 20L                    # how many ranked results the outputs keep

# =============================================================================
# Paths
# =============================================================================
DIR_RAW       <- here("data", "raw")        # never modified
DIR_MANUAL    <- here("data", "manual")     # hand-authored tables (criteria, test cases, facts)
DIR_PROCESSED <- here("data", "processed")
DIR_EXAMPLE   <- here("data", "example")    # toy data so the pipeline runs before the real data exists
DIR_CACHE_API <- here("data", "cache", "api")
DIR_CACHE_LLM <- here("data", "cache", "llm")
DIR_OUTS      <- here("outs")
DIR_FIGS      <- here("outs", "figures")

# Real files win; the toy example is used only when the real one does not exist yet.
USING_EXAMPLE <- FALSE
pick_file <- function(real, example) {
  if (file.exists(real)) return(real)
  USING_EXAMPLE <<- TRUE
  message("NOTE: using TOY EXAMPLE data (", basename(example), "). Real file expected at ",
          sub(paste0(here(), "/"), "", real, fixed = TRUE))
  example
}
ITEMS_FILE      <- pick_file(file.path(DIR_PROCESSED, "items.csv"),      file.path(DIR_EXAMPLE, "items_example.csv"))
CRITERIA_FILE   <- pick_file(file.path(DIR_MANUAL, "criteria.csv"),      file.path(DIR_EXAMPLE, "criteria_example.csv"))
TEST_CASES_FILE <- pick_file(file.path(DIR_MANUAL, "test_cases.csv"),    file.path(DIR_EXAMPLE, "test_cases_example.csv"))
FACTS_FILE      <- pick_file(file.path(DIR_MANUAL, "facts.csv"),         file.path(DIR_EXAMPLE, "facts_example.csv"))

# Pipeline scripts call this first with the input files they read: a real run must never
# rank toy data by accident. Tests and the notebook may still run on the toy files.
stop_if_toy <- function(...) {
  files <- c(...)
  toy <- if (length(files)) any(startsWith(normalizePath(files, mustWork = FALSE), normalizePath(DIR_EXAMPLE, mustWork = FALSE))) else USING_EXAMPLE
  if (toy) stop("Real input missing, refusing to run on TOY example data. See the NOTE lines above.", call. = FALSE)
}

OPPS_FILE       <- file.path(DIR_PROCESSED, "opportunities.csv")
AGENCY_MAP_FILE <- file.path(DIR_MANUAL, "agency_map.csv")
GOALS_FILE      <- here("data", "manual", "agency_goal_summaries.csv")
BACKTEST_CSV    <- file.path(DIR_PROCESSED, "rankings_backtest.csv")
OPEN_STATUSES   <- c("posted", "forecasted", "notice")   # rows in payload.json; closed go to the backtest
FAR_FUTURE_DATE <- as.Date("2030-01-01")   # close dates on or after this read "rolling or no date listed" (decision 8)

# Eligibility (steps 1 and 2). Applicant-type codes checked against single-code rows in
# opportunities.csv: 00 state governments, 06 public higher ed, 25 other (see text), 99 unrestricted.
# Codes 01, 02, 04, 11 and 22 never appear alone in the data [uncertain]; they count as not state-eligible.
ELIG_YES_CODES  <- c("00", "99")              # a state agency can apply
ELIG_ASK_CODES  <- "25"                       # "other": read the text rules, else ask; never hidden
ELIG_HIGHER_ED_CODE   <- "06"                 # public higher ed: eligible only for the agencies below
ELIG_HIGHER_ED_AGENCIES <- c("unc", "ncccs")  # [assumed] the only agencies that are public higher ed
ELIG_TEXT_NO  <- c("state governments are not eligible", "state agencies are not eligible",
                   "applications from federal, state, or tribal governments will not be considered",
                   "tribal governments only", "federally recognized tribes only", "individuals only")
ELIG_TEXT_YES <- c("state governments", "state government agencies", "state agencies", "agencies of state")
# Tribal programs (gate: "tribal-only items are hidden"). An item whose eligibility is still "ask" (code 25 or none)
# and whose TITLE names a tribal program becomes "no", quoting the title words. Titles that also name a State or
# States are left alone ("for State, Territorial, and Tribal", "for States and Tribes"). Kent, Sat Nov 7 evening,
# after the hostile-judge pass found TCUP at DPI #1. 21 open titles match; none with a state-government code.
ELIG_TRIBAL_TITLE <- "\\bTribal\\b|\\bTribes\\b|Indian Reservations?|\\bTCUP\\b"
ELIG_TEXT_NEGATION <- "(not|ineligible|exclud|except)[^.]{0,80}state (government|agenc)"

# Geography: fit is multiplied by GEO_PENALTY when the opportunity TITLE names another US state or
# region and does not name North Carolina. Titles only: summaries list many states in passing.
# 0.5 confirmed by Kent in person (Nov 7); a team judgment, not derived. The item is demoted, never hidden.
GEO_PENALTY <- 0.5

# Overseas posts: a notice whose funder (Grants.gov agency name) is a U.S. Embassy, U.S. Mission or Consulate
# is run by a post abroad for applicants in that country. criteria.csv filter "us_based" drops it. Matched on the
# funder field, not the title. Checked Sat Nov 7: 60 of 1,472 open notices, all State Department posts; Washington
# bureaus (fellowships, ECA, TIP) stay in. Kent's call (Nov 7), after embassy notices showed up in agency lists.
OVERSEAS_POST_PATTERN <- "^\\s*U\\.?S\\.? (Mission|Embassy)\\b|\\bEmbassy\\b|\\bConsulate\\b"
GEO_OTHER_PLACES <- c("Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut","Delaware","Florida",
  "Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana","Maine","Maryland","Massachusetts",
  "Michigan","Minnesota","Mississippi","Missouri","Montana","Nebraska","Nevada","New Hampshire","New Jersey","New Mexico",
  "New York","North Dakota","Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina","South Dakota",
  "Tennessee","Texas","Utah","Vermont","Virginia","Wisconsin","Wyoming","Great Lakes","Pacific Northwest","Northern Forest",
  "Californian","Seattle","Denver","Austin","Chicago","Philadelphia","Gulf of Mexico","Gulf of America","Puerto Rico","Guam","Chesapeake",
  # Added Sat Nov 7 evening (Kent, after the hostile-judge pass found RESTORE Act Gulf Coast at DEQ #3). Each checked against
  # open titles: none names NC. Left out on purpose: "Atlanta" (EDA's Atlanta region serves NC), "Pacific Islands" alone
  # (appears in the HIV Part B formula title, which NC gets), "Southeast" (NC is in it), "Native Hawaiian" (a population).
  "Gulf Coast","Gulf States","RESTORE Act","Great Basin","North Atlantic","Hawai\\S{0,8}-Pacific","Great Plains",
  "Rocky Mountain","Colorado River","Everglades","New England","Northeast Corridor","Midwest","Southwest","American Samoa")

# Program map: a hand table (data/manual/program_map.csv) naming Assistance Listing numbers that belong to an
# agency regardless of keywords. A mapped pair gets fit of at least MAP_FIT_FLOOR (0.8, confirmed by Kent in person Nov 7; a team judgment) and a note saying why.
# It never overrides the eligibility filter.
PROGRAM_MAP_FILE <- file.path(DIR_MANUAL, "program_map.csv")
MAP_FIT_FLOOR    <- 0.8

# AS_OF_DATE is the clock for the scoring and payload step only (10_run_ranking.R, 11_build_payload.R): which open
# rows are still open, days_left, forecast dates that have passed, runway score, closing soon. It moves daily so the
# Top 10 refills as grants expire. Default is today in America/New_York; set env AS_OF_DATE=YYYY-MM-DD for a reproducible
# run (tests and check_facts.R use SNAPSHOT_AS_OF_DATE). REF_DATE above stays fixed and is not used by this step.
AS_OF_TZ   <- "America/New_York"
AS_OF_DATE <- local({
  e <- Sys.getenv("AS_OF_DATE", "")
  if (nzchar(e)) {
    d <- if (grepl("^\\d{4}-\\d{2}-\\d{2}$", e)) suppressWarnings(as.Date(e, optional = TRUE)) else as.Date(NA)
    if (length(d) != 1 || is.na(d)) stop("AS_OF_DATE must be YYYY-MM-DD, got: ", e, call. = FALSE)
    d
  } else as.Date(format(Sys.time(), "%Y-%m-%d", tz = AS_OF_TZ))
})
# Stamped into payload.json: a fixed clock time on the as-of date, so reruns on the same day are identical.
PAYLOAD_AS_OF <- sub("([+-]\\d\\d)(\\d\\d)$", "\\1:\\2",
                     format(as.POSIXct(paste(format(AS_OF_DATE), "11:00:00"), tz = AS_OF_TZ), "%Y-%m-%dT%H:%M:%S%z"))
TOP10_N         <- 10L    # open items flagged per agency (Top 10 list)
COMING_UP_N     <- 10L    # forecasted items kept per agency ("Coming up")
HIDDEN_N        <- 10L    # best-fitting clearly-ineligible items kept per agency so the tool can show the toggle
PLAN_THIN_MIN_BYTES <- 12000L  # [assumed] an agency whose plan text is smaller than this is flagged "plan thin" (the fit score rests on too little text)
BACKTEST_TOP_N  <- 50L    # ranked items written per agency and window in rankings_backtest.csv
SNIPPET_CHARS   <- 240L   # opp_snippet length
TIER_APPROPRIATION_USD <- 1e6  # cost share on an award this large or larger likely needs a state appropriation (same line as the qualifier, APPROPRIATION_THRESHOLD_USD)
CLOSING_SOON_DAYS <- 14L  # [assumed] a Top 10 row with this many days left or fewer counts as closing soon

PAYLOAD_JSON <- file.path(DIR_PROCESSED, "payload.json")
COUNTY_NEED_FILE   <- file.path(DIR_PROCESSED, "county_need.csv")      # from 05a (qualifier caches)
COUNTY_SHAPES_FILE <- file.path(DIR_PROCESSED, "county_shapes.csv")    # from 05c (qualifier tigris cache)
CAPABILITIES_FILE  <- here("data", "qualifier", "agency_capabilities.csv")  # hand-built in the qualifier round; DHHS and DMVA only

# Who a grant reaches (display only; never enters fit, rank, eligibility or tier).
# Population geography (county, congressional district, rurality) comes from the qualifier's payload, built from
# ACS 2023 5-year, CDC PLACES, HRSA and OpenFEMA caches. Tags are keyword rules on the title, then the summary;
# each tag carries the sentence it matched as its quote. Ids match the qualifier's POPULATIONS.
QUALIFIER_PAYLOAD <- here("data", "qualifier", "payload.json")
REACH_MAX_GROUPS  <- 2L     # at most this many groups per grant (title matches first)
REACH_QUOTE_CHARS <- 220L   # quote length cap
# Phrases removed before matching: agency boilerplate and non-population uses of a group word.
GROUP_IGNORE <- paste0("(protect american children|aging (infrastructure|facilit(y|ies)|equipment|systems?|assets?|fleets?|bridges?|roads?|pipes?|water)|aging-related infrastructure|blind spots?",
  "|mother-to-child|senior[ /-]?(key|u\\.?s\\.?|foreign|personnel|officials?|level|investigators?|scientists?|research(ers)?|staff|leaders?|leadership|executives?|advisors?|management)",
  "|(service[- ])?disabled[- ]veteran[- ]owned|veteran[- ]owned|(race|color|religion|sex|age|national origin),? (or |and )?disability|disability shall",
  "|(researchers|scientists|investigators|engineers|faculty) with disabilities|economically disadvantaged wom[ae]n[- ]owned)")
GROUP_RULES <- c(
  children               = "\\b(child|children|childhood|youth|juveniles?|adolescents?|teens?|k-12|kindergarten|elementary|middle schools?|high schools?|school-age|preschool|head start|foster care)\\b",
  older_adults           = "\\b(older adults?|older americans|elderly|aging|seniors?|geriatric|alzheimer'?s|dementia)\\b",
  people_with_disability = "\\b(disabilit(y|ies)|disabled|deaf|blind|hard of hearing|developmental disabilit(y|ies)|vocational rehabilitation)\\b",
  people_in_poverty      = "\\b(low-income|low income|poverty|economically disadvantaged|homeless|homelessness)\\b",
  uninsured              = "\\b(uninsured|underinsured)\\b",
  snap_households        = "\\b(snap|supplemental nutrition assistance|food insecurity|food assistance|wic)\\b",
  recent_births          = "\\b(maternal|prenatal|perinatal|postpartum|pregnan(t|cy)|newborns?|infants?)\\b",
  veterans               = "\\b(veterans?|service members?|military families)\\b",
  adults_mental_distress = "\\b(mental health|behavioral health|suicide|serious mental illness|psychiatric)\\b",
  shortage_area_residents = "\\b(health professional shortage|hpsas?|medically underserved|rural health)\\b",
  hazard_exposed         = "\\b(disasters?|hazard mitigation|flood(s|ing)?|wildfires?|hurricanes?|emergency management)\\b"
)
CAPABILITY_AGENCY_IDS <- c(DHHS = "dhhs", DMVA = "dmva")
NOTICE_READER_CSV  <- file.path(DIR_PROCESSED, "notice_reader.csv")  # from 30_notice_reader.R; optional, merged into payload rows
RANKING_CSV  <- file.path(DIR_PROCESSED, "ranking.csv")
TOOL_HTML_OUT <- file.path(DIR_OUTS, "criteria_tool.html")
TOOL_MAX_BYTES <- 25 * 1024^2

# =============================================================================
# Opportunity sources (data setup). Keys are read from .Renviron only, never written here.
# =============================================================================
# Team keys live in api_keys.env at the project root (private repo, Kent's decision). Loaded here
# so every script sees SIMPLER_GRANTS_KEY and SAM_API_KEY through Sys.getenv().
if (file.exists(here("api_keys.env"))) readRenviron(here("api_keys.env"))
DIR_CACHE_GRANTS   <- here("data", "cache", "api", "grantsgov")
DIR_CACHE_EXTRACT  <- here("data", "cache", "api", "grantsgov_extract")
CLOSED_SINCE       <- as.Date("2024-11-06")   # keep closed/archived items closing on or after this
USA_FY             <- 2022:2026               # USAspending fiscal years for the "won before" signal
API_SLEEP_SEC      <- 0.4                     # politeness delay before each uncached call
GRANTSGOV_API_BASE <- "https://api.grants.gov/v1/api"
GRANTSGOV_EXTRACT_PAGE <- "https://www.grants.gov/xml-extract"   # confirm the live file URL here
USASPENDING_BASE   <- "https://api.usaspending.gov/api/v2"
FR_API_BASE        <- "https://www.federalregister.gov/api/v1"
SIMPLER_BASE       <- "https://api.simpler.grants.gov"      # key: SIMPLER_GRANTS_KEY
SAM_AL_BASE        <- "https://api.sam.gov/assistance-listings/v1"  # key: SAM_API_KEY
USDOT_GRANTS_URL   <- "https://www.transportation.gov/grants"        # [uncertain] verify page before scraping

# =============================================================================
# Evaluation, refresh and feedback (plan review amendments, planning/08_product_decisions.md)
# =============================================================================
FLAG_TOP_N          <- 10L               # flagged items per agency per window (amendment D)
WINDOW_WEEKS        <- c(2L, 4L, 6L)     # backtest windows for the recall curve (amendment E)
WINDOW_DEFAULT_WEEKS <- 2L               # UI default and headline window
IN_TIME_DAYS        <- 21L               # catch counts as in time if this many days remain (team assumption, amendment F)
POOL_PER_AGENCY     <- 20L               # hand-labelled pool size per agency
POOL_SEED           <- 20261106L         # fixed seed for the pool draw (amendment C)
POOL_CATEGORY_SHARE <- 0.5               # share drawn from the agency's matching Grants.gov category
MODEL_LABEL_MIN_CATCH <- 0.80            # model must catch this share of hand "relevant" items (amendment B)
MODEL_LABEL_MIN_KAPPA <- 0.60            # and reach this kappa on relevant vs not relevant
ROCCHIO_GOOD_WEIGHT <- 0.25              # feedback: weight of "good" items added to the profile (amendment I)
ROCCHIO_BAD_WEIGHT  <- 0.10              # feedback: weight of "bad" items subtracted [assumed, untested]

# Held-out label check (Noah, 40_label_check.R). Draw rule and word list are judgment calls.
HOLDOUT_AGENCIES <- c("Department of Justice", "Department of Agriculture and Consumer Services",
                      "Department of Labor")   # model-labelled, not in the validate set
N_TOP <- 5
N_RANDOM <- 5
HOLDOUT_SEED <- 2026
POOL_STATUSES <- c("posted", "forecasted", "notice")
SUMMARY_CHARS <- 500
# Words too common in plans and notices to count as a match (short list; a judgment call)
GENERIC_WORDS <- c("north","carolina","state","states","department","program","programs","public",
  "service","services","improve","ensure","support","strengthen","across","throughout","advance",
  "expand","enhance","leading","excellence","operations","efficiency","collaboration","customer",
  "community","communities","local","provide","work","using","goals","every","people","system",
  "systems","national","federal","future","serve","working","fully","change","grant","grants",
  "funding","award","awards","project","projects","applicants","application","information",
  "development","management","include","includes","including","based","their","which","through")

# County need (Noah, 05a_county_need.R; copied from archive/qualifier/src/R/00_config.R)
OVERDOSE_YEARS <- 2019:2021   # NCHS model-based drug poisoning death rates, averaged
HPSA_AREA_TYPES <- c("Hpsa Geo", "Hpsa Geo HN", "Hpsa Pop")   # area designations only, not facilities

# =============================================================================
# Tool controls
# =============================================================================
WEIGHT_RANGE <- c(0, 3)
WEIGHT_STEP  <- 0.5

# =============================================================================
# Local LLM (Ollama). Only used for text labeling; it never ranks or decides.
# =============================================================================
OLLAMA_URL         <- "http://localhost:11434"
LLM_MODEL          <- "qwen2.5:14b"   # same model as the qualifier; check `ollama list` on each laptop
LLM_PROMPT_VERSION <- "v1"            # bump to invalidate cached labels after changing a prompt
LLM_SEED           <- 42L
LLM_TIMEOUT_SEC    <- 180

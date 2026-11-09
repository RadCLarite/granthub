# 05_export_tool_data.R — writes data/processed/payload.json, the tool's data contract.
#
# R computes every weight-independent attribute here. The tool (src/tool/tiering.js)
# computes only tiers and ordering from these attributes plus the user's settings.
# Nothing in this file decides a tier.
#
# Run: Rscript src/R/05_export_tool_data.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(stringr); library(purrr); library(tibble)
  library(jsonlite); library(sf); library(httr2)
})

# ---- County indicators ----------------------------------------------------------------

acs_county_vars <- c(
  pop = "B01003_001", under18 = "B09001_001",
  pov_u18_num = "B17001_004", pov_u18_a = "B17001_005", pov_u18_b = "B17001_006",
  pov_u18_c = "B17001_007", pov_u18_d = "B17001_008", pov_u18_e = "B17001_009",
  pov_u18_f = "B17001_018", pov_u18_g = "B17001_019", pov_u18_h = "B17001_020",
  pov_u18_i = "B17001_021", pov_u18_j = "B17001_022", pov_u18_k = "B17001_023",
  births = "B13002_002", women_15_50 = "B13002_001",
  veterans = "B21001_002", civ_18plus = "B21001_001",
  pov_total = "B17001_002", snap_hh = "B22010_002", households = "B22010_001"
)

get_acs_nc <- function(geography) {
  path <- file.path(DIR_CACHE_API, paste0("acs_", ACS_YEAR, "_nc_", gsub(" ", "_", geography), ".rds"))
  # The committed cache is enough; a Census key is only needed to fetch it the first time.
  if (file.exists(path)) return(readRDS(path))
  if (!nzchar(CENSUS_API_KEY)) return(NULL)
  get_cached(path, function() {
    tidycensus::census_api_key(CENSUS_API_KEY, install = FALSE)
    subj <- tidycensus::get_acs(geography = geography, state = NC_FIPS, year = ACS_YEAR, survey = "acs5",
                                variables = c(age65 = "S0101_C01_030", disab = "S1810_C02_001",
                                              uninsured = "S2701_C04_001"))
    det <- tidycensus::get_acs(geography = geography, state = NC_FIPS, year = ACS_YEAR, survey = "acs5",
                               variables = acs_county_vars)
    bind_rows(det, subj) |> select(GEOID, NAME, variable, estimate) |>
      pivot_wider(names_from = variable, values_from = estimate)
  })
}

get_fema_declarations <- function() {
  get_cached(file.path(DIR_CACHE_API, "fema_declarations_nc.rds"), function() {
    url <- paste0("https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries",
                  "?$filter=state%20eq%20%27NC%27%20and%20declarationDate%20ge%20%27",
                  format(FEMA_DECLARATIONS_SINCE), "T00:00:00.000z%27&$top=10000&$format=json")
    j <- request(url) |> req_timeout(120) |> req_perform() |> resp_body_json(simplifyVector = TRUE)
    as_tibble(j$DisasterDeclarationsSummaries)
  })
}

# Geographic and population-group shortage designations only. Facility designations
# (FQHCs, rural health clinics, prisons) are excluded because they overlap the others,
# and each designation is counted once, so totals cannot exceed the population.
HPSA_AREA_TYPES <- c("Hpsa Geo", "Hpsa Geo HN", "Hpsa Pop")

hrsa_designated <- function(file) {
  readRDS(file.path(DIR_CACHE_API, file)) |>
    filter(common_state_abbreviation == "NC", hpsa_status_code == "D", hpsa_type_code %in% HPSA_AREA_TYPES) |>
    mutate(fips = str_pad(state_and_county_federal_information_processing_standard_code, 5, pad = "0"))
}

hrsa_county <- function(file) {
  hrsa_designated(file) |> distinct(hpsa_id, fips) |> count(fips, name = "hpsa_count")
}

hrsa_state_population <- function(file) {
  d <- hrsa_designated(file) |> distinct(hpsa_id, .keep_all = TRUE)
  sum(as.numeric(d$hpsa_designation_population), na.rm = TRUE)
}

# Model-based drug poisoning death rates by county (NCHS, ICD-10 X40-X44, X60-X64, X85,
# Y10-Y14), averaged over OVERDOSE_YEARS. Open CDC data: no agreement, no suppressed cells.
# (CDC WONDER's API does not serve county-level mortality.)
get_overdose_rates <- function() {
  get_cached(file.path(DIR_CACHE_API, "nchs_drug_poisoning_nc_county.rds"), function() {
    url <- paste0("https://data.cdc.gov/resource/rpvx-m2md.json?state=North%20Carolina&$limit=5000")
    as_tibble(request(url) |> req_timeout(120) |> req_perform() |> resp_body_json(simplifyVector = TRUE))
  })
}

build_county_indicators <- function() {
  raw <- readRDS(file.path(DIR_CACHE_API, "places_nc_county.rds"))
  places <- tibble(fips = sprintf("%05d", as.integer(raw$countyfips)), county = raw$countyname,
                   pop_places = as.numeric(raw$totalpopulation), adults = as.numeric(raw$totalpop18plus))
  for (m in c("mhlth", "depression", "binge", "csmoking", "access2", "foodinsecu", "foodstamp",
              "disability", "cognition", "lacktrpt", "housinsecu")) {
    places[[m]] <- as.numeric(raw[[paste0(m, "_crudeprev")]])
  }
  pc <- hrsa_county("hrsa_pc.rds") |> rename(pc_hpsa_count = hpsa_count)
  mh <- hrsa_county("hrsa_mh.rds") |> rename(mh_hpsa_count = hpsa_count)
  fema <- get_fema_declarations()
  fema_c <- if (is.null(fema)) tibble(fips = character(), fema_declarations = numeric()) else
    fema |> mutate(fips = paste0(fipsStateCode, fipsCountyCode)) |>
      distinct(disasterNumber, fips) |> count(fips, name = "fema_declarations")
  od <- get_overdose_rates()
  od_c <- if (is.null(od)) tibble(fips = character(), overdose_rate = numeric()) else
    od |> filter(as.integer(year) %in% OVERDOSE_YEARS) |>
      mutate(fips = sprintf("%05d", as.integer(fips)), rate = as.numeric(model_based_death_rate)) |>
      group_by(fips) |> summarise(overdose_rate = mean(rate, na.rm = TRUE), .groups = "drop")
  acs <- get_acs_nc("county")
  acs_c <- if (is.null(acs)) tibble(fips = character()) else
    acs |> transmute(fips = GEOID, acs_pop = pop,
                     child_poverty_rate = rowSums(across(starts_with("pov_u18_")) ) / under18,
                     birth_rate = births / women_15_50,
                     age65_share = age65 / pop,
                     veteran_share = veterans / civ_18plus)
  places |> left_join(pc, by = "fips") |> left_join(mh, by = "fips") |>
    left_join(fema_c, by = "fips") |> left_join(acs_c, by = "fips") |> left_join(od_c, by = "fips") |>
    mutate(across(c(pc_hpsa_count, mh_hpsa_count, fema_declarations), ~ coalesce(as.numeric(.x), 0)))
}

# Each domain's need index is the mean percentile rank (0-1) of its indicators across
# NC's 100 counties. Indicators and their sources are exported with the index so the
# tool can show exactly what the color means.
domain_indicators <- function() list(
  D01 = c(mhlth = "Adults with frequent mental distress (CDC PLACES)",
          depression = "Adults with depression (CDC PLACES)",
          mh_hpsa_count = "Mental health shortage areas (HRSA)"),
  D02 = c(overdose_rate = paste0("Drug poisoning deaths per 100,000, ", min(OVERDOSE_YEARS), "-", max(OVERDOSE_YEARS),
                                  " average (NCHS model-based county estimates)"),
          binge = "Binge drinking (CDC PLACES)"),
  D03 = c(birth_rate = "Births per woman aged 15-50 (ACS)",
          access2 = "Adults 18-64 without insurance (CDC PLACES)"),
  D04 = c(child_poverty_rate = "Children below poverty (ACS)",
          housinsecu = "Housing insecurity (CDC PLACES)"),
  D05 = c(foodinsecu = "Food insecurity (CDC PLACES)",
          foodstamp = "Received SNAP (CDC PLACES)"),
  D06 = c(disability = "Any disability (CDC PLACES)", cognition = "Cognitive disability (CDC PLACES)",
          age65_share = "Share aged 65+ (ACS)"),
  D07 = c(access2 = "Adults 18-64 without insurance (CDC PLACES)",
          lacktrpt = "Lack of reliable transportation (CDC PLACES)",
          pc_hpsa_count = "Primary care shortage designations (HRSA)"),
  D08 = c(fema_declarations = paste0("FEMA disaster declarations since ", format(FEMA_DECLARATIONS_SINCE, "%Y"), " (OpenFEMA)"),
          housinsecu = "Housing insecurity (CDC PLACES)")
)

build_domain_need <- function(ci) {
  imap(domain_indicators(), function(inds, dom) {
    avail <- names(inds)[names(inds) %in% names(ci) & map_lgl(names(inds), ~ .x %in% names(ci) && any(!is.na(ci[[.x]])))]
    if (length(avail) == 0) return(list(id = dom, available = FALSE, indicators = list(), index = list()))
    pr <- as.data.frame(map(avail, ~ percent_rank(ci[[.x]]))); names(pr) <- avail
    idx <- rowMeans(pr, na.rm = TRUE)
    list(id = dom, available = TRUE,
         indicators = map(avail, ~ list(id = .x, label = inds[[.x]])),
         missing_indicators = I(setdiff(names(inds), avail)),
         index = as.list(setNames(round(idx, 3), ci$fips)),
         values = map(setNames(avail, avail), ~ as.list(setNames(round(ci[[.x]], 4), ci$fips))))
  })
}

# ---- Population counts for reach vs intensity ---------------------------------------------

build_populations <- function(ci) {
  acs_state <- get_acs_nc("state")
  s <- function(v) if (is.null(acs_state) || !v %in% names(acs_state)) NA_real_ else sum(acs_state[[v]])
  mh_pop <- sum(ci$mhlth / 100 * ci$adults, na.rm = TRUE)
  counts <- list(
    all_residents = list(n = s("pop"), source = paste("ACS", ACS_YEAR, "5-year B01003")),
    children = list(n = s("under18"), source = paste("ACS", ACS_YEAR, "5-year B09001")),
    older_adults = list(n = s("age65"), source = paste("ACS", ACS_YEAR, "5-year S0101")),
    people_with_disability = list(n = s("disab"), source = paste("ACS", ACS_YEAR, "5-year S1810")),
    people_in_poverty = list(n = s("pov_total"), source = paste("ACS", ACS_YEAR, "5-year B17001")),
    uninsured = list(n = s("uninsured"), source = paste("ACS", ACS_YEAR, "5-year S2701")),
    snap_households = list(n = s("snap_hh"), source = paste("ACS", ACS_YEAR, "5-year B22010 (households)")),
    recent_births = list(n = s("births"), source = paste("ACS", ACS_YEAR, "5-year B13002")),
    veterans = list(n = s("veterans"), source = paste("ACS", ACS_YEAR, "5-year B21001")),
    adults_mental_distress = list(n = round(mh_pop), source = "CDC PLACES frequent mental distress x adult population, summed over counties"),
    people_with_sud = list(n = NA_real_, source = "Not available: no NC substance use disorder count in hand"),
    shortage_area_residents = list(n = hrsa_state_population("hrsa_pc.rds"), source = "HRSA primary care HPSA designation population: geographic and population-group designations, each counted once"),
    hazard_exposed = list(n = sum(ci$pop_places[ci$fema_declarations >= quantile(ci$fema_declarations, 0.75, na.rm = TRUE)], na.rm = TRUE),
                          source = paste0("Population of counties in the top quarter of FEMA declarations since ", format(FEMA_DECLARATIONS_SINCE, "%Y"))),
    system_level = list(n = NA_real_, source = "No direct beneficiaries; per-person cost not meaningful")
  )
  imap(counts, ~ c(list(id = .y, label = POPULATIONS[[.y]]), .x))
}

# ---- Where each population lives: counties, rurality, congressional districts -----------------

# NC Rural Center definition: rural = 250 people per square mile or fewer; urban = more than
# 750; regional city / suburban in between. Applied here to ACS population and TIGER land area.
RURALITY_CUTS <- c(rural = 250, urban = 750)

county_rurality <- function(acs) {
  cty <- readRDS(file.path(DIR_CACHE_GEO, "nc_county_2023.rds")) |> sf::st_drop_geometry() |>
    transmute(fips = GEOID, sq_mi = as.numeric(ALAND) / 2589988.11)
  acs |> transmute(fips = GEOID, pop) |> inner_join(cty, by = "fips") |>
    mutate(density = pop / sq_mi,
           rurality = case_when(density <= RURALITY_CUTS[["rural"]] ~ "rural",
                                density > RURALITY_CUTS[["urban"]] ~ "urban",
                                TRUE ~ "suburban"))
}

# Primary care shortage-area residents by county. A designation spanning several counties has
# its population split evenly across them (an approximation; HRSA does not publish the split).
hrsa_county_population <- function(file) {
  hrsa_designated(file) |> distinct(hpsa_id, fips, .keep_all = TRUE) |>
    mutate(pop = as.numeric(hpsa_designation_population)) |>
    group_by(hpsa_id) |> mutate(pop = pop / n()) |> ungroup() |>
    group_by(fips) |> summarise(n = sum(pop, na.rm = TRUE), .groups = "drop")
}

# Adds county (and, where the ACS publishes it, congressional-district) counts to each
# population, so the tool can show where the people an opportunity serves live.
add_population_geography <- function(populations, ci) {
  acs <- get_acs_nc("county")
  cd <- get_acs_nc("congressional district")
  if (is.null(acs)) return(populations)
  acs_var <- c(all_residents = "pop", children = "under18", older_adults = "age65",
               people_with_disability = "disab", people_in_poverty = "pov_total", uninsured = "uninsured",
               snap_households = "snap_hh", recent_births = "births", veterans = "veterans")
  hz_cut <- quantile(ci$fema_declarations, 0.75, na.rm = TRUE)
  other <- list(
    adults_mental_distress = setNames(ci$mhlth / 100 * ci$adults, ci$fips),
    shortage_area_residents = with(hrsa_county_population("hrsa_pc.rds"), setNames(n, fips)),
    hazard_exposed = setNames(ifelse(ci$fema_declarations >= hz_cut, ci$pop_places, 0), ci$fips))
  as_counts <- function(v) as.list(round(v[!is.na(v)]))
  imap(populations, function(p, id) {
    if (id %in% names(acs_var)) {
      p$county <- as_counts(setNames(acs[[acs_var[[id]]]], acs$GEOID))
      if (!is.null(cd)) p$district <- as_counts(setNames(cd[[acs_var[[id]]]], cd$GEOID))
    } else if (id %in% names(other)) {
      p$county <- as_counts(other[[id]])
    }
    p
  })
}

community_context <- function() {
  acs <- get_acs_nc("county")
  cd <- get_acs_nc("congressional district")
  if (is.null(acs)) return(NULL)
  r <- county_rurality(acs)
  list(
    county_pop = as.list(setNames(acs$pop, acs$GEOID)),
    county_rurality = as.list(setNames(r$rurality, r$fips)),
    rurality_rule = "NC Rural Center definition applied to ACS 2023 population and Census land area: rural = 250 people per square mile or fewer; urban = more than 750; regional city or suburban in between.",
    district_names = if (!is.null(cd)) as.list(setNames(str_remove(cd$NAME, " \\(.*$"), cd$GEOID)) else NULL,
    district_note = "Congressional districts as drawn for the 118th Congress (2023-2024), matching the ACS 2019-2023 estimates. North Carolina redrew its districts for the 2024 election, so current districts differ.",
    caveat = "Where the people this opportunity serves live, not where the money would be spent. Most awards are statewide."
  )
}

# ---- Geography ----------------------------------------------------------------------------

sf_to_geojson <- function(x, keep, props) {
  x <- st_transform(x, 4326)
  if (!is.na(keep) && keep < 1) x <- rmapshaper::ms_simplify(x, keep = keep, keep_shapes = TRUE)
  x <- x[, props]
  tmp <- tempfile(fileext = ".geojson")
  st_write(x, tmp, driver = "GeoJSON", quiet = TRUE,
           layer_options = c("COORDINATE_PRECISION=4", "RFC7946=YES"))
  on.exit(unlink(tmp))
  gj <- fromJSON(paste(readLines(tmp, warn = FALSE), collapse = ""), simplifyVector = FALSE)
  gj$name <- NULL   # GDAL names the layer after the temporary file; drop it so builds are reproducible
  gj
}

build_geo <- function() {
  files <- c(county = "nc_county_2023.rds", congressional_district = "nc_congressional_district_2023.rds",
             tract = "nc_tract_2023.rds", place = "nc_place_2023.rds")
  imap(files, function(f, geo) {
    path <- file.path(DIR_CACHE_GEO, f)
    if (!file.exists(path)) return(NULL)
    x <- readRDS(path)
    x$fips <- if (geo == "county") x$GEOID else NA_character_
    x$name <- dplyr::coalesce(x$NAMELSAD, x$NAME, x$GEOID)
    sf_to_geojson(x, GEO_SIMPLIFY_KEEP[[geo]], c("fips", "name"))
  }) |> compact()
}

# ---- Opportunities: merge rule signals with validated LLM labels ------------------------------

merge_labels <- function(reqs, labels) {
  if (is.null(labels)) return(reqs |> mutate(llm_labeled = FALSE))
  l <- labels |> filter(labeled)
  reqs |>
    left_join(l, by = "opportunity_number") |>
    mutate(
      llm_labeled = coalesce(labeled, FALSE),
      rule_capabilities = required_capabilities,
      required_capabilities = if_else(llm_labeled, llm_capabilities, required_capabilities),
      subrecipient_required = if_else(llm_labeled, llm_subrecipient, subrecipient_required),
      evaluation_required = if_else(llm_labeled, llm_evaluation, evaluation_required),
      is_capital_project = if_else(llm_labeled, llm_capital, is_capital_project),
      needs_formal_designation = if_else(llm_labeled, llm_designation, needs_formal_designation),
      # Cost share: the structured flag, or the model found a match requirement with a quote.
      match_required = match_required | (llm_labeled & coalesce(llm_match_required, FALSE) &
                                           nzchar(coalesce(llm_match_evidence, "")) &
                                           coalesce(llm_match_evidence, "") != "none"),
      match_pct = coalesce(match_pct, llm_match_pct),
      domain = if_else(llm_labeled & !is.na(llm_domain) & llm_domain != "none", llm_domain, domain),
      requirement_source = if_else(llm_labeled, paste0("llm:", LLM_LABEL_MODEL, ":", LLM_PROMPT_VERSION), requirement_source),
      instrument_burden = case_when(
        instrument == "cooperative_agreement" & (subrecipient_required | evaluation_required) ~ "high",
        instrument == "cooperative_agreement" | subrecipient_required | evaluation_required  ~ "medium",
        TRUE ~ "low")
    )
}

# Audience: the issuing agency's own opportunities, plus anything the labeler rated
# at least AUDIENCE_MIN_LEVEL aligned *and* placed in one of the eight domains.
# Unlabeled rows (NIH and other screened items) fall back to: VA-issued → DMVA, else DHHS.
audience_from_labels <- function(m) {
  ok_level <- LABEL_LEVELS[seq_len(match(AUDIENCE_MIN_LEVEL, LABEL_LEVELS))]
  in_domain <- !is.na(m$llm_domain) & m$llm_domain != "none"
  map(seq_len(nrow(m)), function(i) {
    if (!isTRUE(m$llm_labeled[i])) return(if (m$is_va[i]) "DMVA" else "DHHS")
    a <- character()
    if (m$llm_align_dhhs[i] %in% ok_level && in_domain[i]) a <- c(a, "DHHS")
    if (m$is_va[i] || (m$llm_align_dmva[i] %in% ok_level && in_domain[i])) a <- c(a, "DMVA")
    a
  })
}

# Opportunities that do not list state governments as eligible get a minimal record, so
# the tool can account for all 1,662 ("outside your scope") without tiering them.
out_of_scope_records <- function(g) {
  g <- g |> filter(!state_eligible)
  close <- if_else(g$status_group == "Forecasted", g$forecasted_close_date, g$close_date)
  map(seq_len(nrow(g)), function(i) list(
    number = g$opportunity_number[i], title = g$opportunity_title[i], agency_code = g$agency_code[i],
    url = g$url[i], status = tolower(g$status_group[i]), state_eligible = FALSE,
    close_day = as.integer(close[i]), audience = I(character()),
    applicant_types = paste(g$applicant_type_list[[i]], collapse = ", ")))
}

# Award amounts and deadlines as Grants.gov publishes them (01c_grantsgov_awards.R). The award is
# the current record's stated award ceiling. Where Grants.gov states no ceiling, it is estimated as
# total program funding / expected number of awards (Grants.gov's figures, else the export's) and
# labeled as an estimate. The deadline is Grants.gov's current application deadline (estimated,
# for forecasts); the export's date is used only when Grants.gov has none.
apply_grantsgov_awards <- function(m, awards) {
  if (is.null(awards)) return(m |> mutate(award_floor_usd = NA_real_, deadline_source = "export",
                                          gg_deadline = as.Date(NA), gg_record = NA_character_))
  m |> left_join(select(awards, opportunity_number, gg_record, gg_award_ceiling, gg_award_floor, gg_deadline,
                        gg_est_funding, gg_n_awards), by = "opportunity_number") |>
    mutate(
      gg_divided = if_else(!is.na(gg_est_funding) & !is.na(gg_n_awards) & gg_n_awards > 0,
                           gg_est_funding / gg_n_awards, NA_real_),
      stated = if_else(!is.na(gg_record), gg_award_ceiling, award_ceiling_clean),
      estimated = coalesce(gg_divided, implied_award_usd),
      award_estimate_usd = coalesce(stated, estimated),
      award_basis = case_when(!is.na(stated) & !is.na(gg_record) ~ "grantsgov_ceiling",
                              !is.na(stated) ~ "ceiling",
                              !is.na(estimated) ~ "total_over_awards",
                              TRUE ~ NA_character_),
      award_floor_usd = gg_award_floor,
      deadline_source = if_else(!is.na(gg_deadline), "grantsgov", "export"))
}

opportunity_records <- function(m, alignment, enrich, populations, awards = NULL) {
  m <- m |> filter(state_eligible) |> apply_grantsgov_awards(awards)
  aud <- audience_from_labels(m)
  st <- enrich$status |> select(opportunity_number, status_now, close_date_now, status_checked)
  m <- m |> left_join(st, by = "opportunity_number") |>
    left_join(select(enrich$nofo, opportunity_number, nofo_chars), by = "opportunity_number")
  close <- if_else(m$status_group == "Forecasted", m$forecasted_close_date, m$close_date)
  export_close <- close   # the export's own date, kept for the verified-facts check
  close <- if_else(!is.na(m$gg_deadline), m$gg_deadline, close)
  post  <- if_else(m$status_group == "Forecasted", m$forecasted_post_date, m$post_date)
  al <- alignment |> select(opportunity_number, agency, emb_pct, emb_best_id)
  pop_n <- map_dbl(populations, ~ .x$n %||% NA_real_)
  map(seq_len(nrow(m)), function(i) {
    r <- m[i, ]
    a <- al[al$opportunity_number == r$opportunity_number, ]
    llm_al <- list(DHHS = list(level = r$llm_align_dhhs, row = r$llm_align_dhhs_row, why = r$llm_align_dhhs_why),
                   DMVA = list(level = r$llm_align_dmva, row = r$llm_align_dmva_row, why = r$llm_align_dmva_why))
    alignment_rec <- setNames(map(c("DHHS", "DMVA"), function(ag) {
      e <- a[a$agency == ag, ]
      list(pct = if (nrow(e)) round(e$emb_pct, 3) else NULL,
           embed_best_id = if (nrow(e)) e$emb_best_id else NULL,
           llm_level = if (isTRUE(r$llm_labeled)) llm_al[[ag]]$level else NULL,
           llm_row = if (isTRUE(r$llm_labeled)) llm_al[[ag]]$row else NULL,
           llm_why = if (isTRUE(r$llm_labeled)) llm_al[[ag]]$why else NULL)
    }), c("DHHS", "DMVA"))
    pop_id <- if (isTRUE(r$llm_labeled)) r$llm_population else NA_character_
    people <- if (!is.na(pop_id)) pop_n[[pop_id]] else NA_real_
    list(
      id = r$opportunity_id, number = r$opportunity_number, title = r$opportunity_title, state_eligible = TRUE,
      agency_code = r$agency_code, agency_name = r$agency_name, url = r$url,
      status = tolower(r$status_group),
      status_now = r$status_now, status_checked = str_sub(r$status_checked, 1, 10),
      audience = I(as.character(aud[[i]])),
      post_day = as.integer(post[i]), close_day = as.integer(close[i]),
      export_close_day = as.integer(export_close[i]),
      award_estimate_usd = r$award_estimate_usd, award_basis = r$award_basis,
      award_floor_usd = r$award_floor_usd, deadline_source = r$deadline_source,
      ceiling_usd = r$award_ceiling_clean, expected_awards = r$expected_number_of_awards,
      instrument = r$instrument, instrument_burden = r$instrument_burden,
      cost_share = isTRUE(r$match_required), match_pct = r$match_pct,
      match_evidence = if (isTRUE(r$llm_labeled)) r$llm_match_evidence else NULL,
      subrecipient_required = isTRUE(r$subrecipient_required),
      evaluation_required = isTRUE(r$evaluation_required),
      is_capital_project = isTRUE(r$is_capital_project),
      needs_formal_designation = isTRUE(r$needs_formal_designation),
      required_capabilities = I(as.character(unique(unlist(r$required_capabilities)))),
      domain = r$domain, division = if (isTRUE(r$llm_labeled)) r$llm_division else NULL,
      administrable = if (isTRUE(r$llm_labeled)) r$llm_administrable else NULL,
      is_renewal = if (isTRUE(r$llm_labeled)) r$llm_renewal else NULL,
      target_population = pop_id, people_est = people,
      alignment = alignment_rec,
      screen = list(is_nih = r$is_nih, is_research_mechanism = r$is_research_mechanism,
                    is_restricted = r$is_restricted_competition,
                    not_administrable = isTRUE(r$llm_labeled) && identical(r$llm_administrable, FALSE)),
      has_full_announcement = coalesce(r$nofo_chars, 0L) > 0,
      provenance = list(cost_share = if (isTRUE(r$is_cost_sharing)) "csv:is_cost_sharing"
                                     else if (isTRUE(r$match_required)) "llm:full-announcement quote" else "csv:is_cost_sharing",
                        requirements = r$requirement_source),
      summary_snippet = str_sub(r$summary_text, 1, 700)
    )
  })
}

# ---- Config block exported to JS --------------------------------------------------------------

export_config <- function() {
  base <- default_settings()
  opening <- modifyList(base, keep(PRESETS, ~ .x$id == DEFAULT_PRESET_ID)[[1]]$settings)
  list(
    defaults = base, opening = opening, opening_preset = DEFAULT_PRESET_ID,
    ranges = list(runway_days = RUNWAY_DAYS_RANGE, staff_fte = c(STAFF_FTE_RANGE, STAFF_FTE_STEP),
                  min_award_usd = c(MIN_AWARD_RANGE, MIN_AWARD_STEP)),
    match_levels = MATCH_AUTHORITY_LEVELS, agencies = AGENCIES,
    presets = PRESETS, parser_domain_boost = PARSER_DOMAIN_BOOST, rescue_pct = ALIGNMENT_RESCUE_PCT,
    fact_ref_date = format(FACT_REF_DATE), pull_date = format(PULL_DATE)
  )
}

# ---- Assemble, validate, write --------------------------------------------------------------------

validate_payload <- function(p) {
  req_top <- c("schema_version", "meta", "config", "capabilities", "domains", "priorities",
               "populations", "opportunities", "geo", "golden")
  miss <- setdiff(req_top, names(p)); if (length(miss)) stop("payload missing: ", paste(miss, collapse = ", "))
  req_opp <- c("number", "title", "status", "audience", "close_day", "award_estimate_usd", "instrument",
               "instrument_burden", "cost_share", "subrecipient_required", "evaluation_required",
               "is_capital_project", "needs_formal_designation", "required_capabilities", "domain", "screen")
  if (length(p$opportunities) != nrow(grants)) stop("payload has ", length(p$opportunities), " opportunities; expected all ", nrow(grants))
  bad <- keep(p$opportunities, ~ isTRUE(.x$state_eligible) && length(setdiff(req_opp, names(.x))) > 0)
  if (length(bad)) stop(length(bad), " opportunity records are missing required fields")
  caps <- unique(unlist(map(p$opportunities, "required_capabilities")))
  if (length(setdiff(caps, CAPABILITIES))) stop("unknown capability ids: ", paste(setdiff(caps, CAPABILITIES), collapse = ", "))
  invisible(TRUE)
}

build_payload <- function() {
  set.seed(SEED)
  enrich <- readRDS(file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))
  alignment <- readRDS(file.path(DIR_PROCESSED, "alignment.rds"))
  labels_path <- file.path(DIR_PROCESSED, "llm_labels.rds")
  labels <- if (file.exists(labels_path)) readRDS(labels_path) else NULL
  reqs <- extract_requirements(grants)
  merged <- merge_labels(reqs, labels)
  ci <- build_county_indicators()
  populations <- add_population_geography(build_populations(ci), ci)
  awards_path <- file.path(DIR_PROCESSED, "grantsgov_awards.rds")
  awards <- if (file.exists(awards_path)) readRDS(awards_path) else NULL
  opps <- c(opportunity_records(merged, alignment, enrich, populations, awards), out_of_scope_records(grants))
  profiles <- build_capability_profiles()
  pr <- load_priorities()
  p <- list(
    schema_version = PAYLOAD_SCHEMA_VERSION,
    meta = list(built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), source_file = basename(GRANTS_CSV),
                pull_date = format(PULL_DATE), source_rows = nrow(grants), payload_rows = length(opps),
                llm_model = LLM_LABEL_MODEL, llm_prompt_version = LLM_PROMPT_VERSION,
                llm_labeled = sum(merged$llm_labeled & merged$state_eligible),
                assumptions = list(appropriation_usd = APPROPRIATION_THRESHOLD_USD,
                                   fte_by_burden = as.list(FTE_BY_BURDEN),
                                   audience_min_level = AUDIENCE_MIN_LEVEL,
                                   exclude_internal_ops = ALIGN_EXCLUDE_INTERNAL_OPS)),
    config = export_config(),
    capabilities = list(vocab = map(CAPABILITIES, ~ list(id = .x, label = profiles$DHHS[[.x]]$label)),
                        profiles = profiles),
    domains = map(names(DOMAINS), ~ list(id = .x, label = DOMAINS[[.x]])),
    domain_need = build_domain_need(ci),
    county_names = as.list(setNames(ci$county, ci$fips)),
    priorities = split(pr, pr$agency) |> map(~ setNames(map(.x$text, ~ .x), .x$priority_id)),
    populations = populations,
    community = community_context(),
    opportunities = opps,
    geo = build_geo(),
    golden = list(fact_universe_count = 296L, fact_nih_count = 272L)
  )
  # Opening-state tier counts, computed by the same JS the tool runs.
  flat <- run_tiering_js(p$opportunities, p$capabilities$profiles, p$config$opening)
  p$golden$opening_counts <- as.list(table(ifelse(flat$placement == "pile", paste0("tier", flat$tier), flat$placement)))
  validate_payload(p)
  p
}

write_payload <- function(p, path = PAYLOAD_JSON) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(toJSON(p, auto_unbox = TRUE, null = "null", na = "null", digits = NA), path, useBytes = TRUE)
  path
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/05_export_tool_data.R")
  for (f in c("00_config", "01_load_clean", "01a_grantsgov_enrich", "01b_alignment",
              "02_capabilities", "03_llm_label"))
    source(here::here("src", "R", paste0(f, ".R")))
  p <- build_payload()
  path <- write_payload(p)
  message("Wrote ", path, " (", round(file.size(path) / 1024^2, 2), " MB, ",
          length(p$opportunities), " opportunities)")
  message("Opening-state counts: ", paste(names(p$golden$opening_counts), unlist(p$golden$opening_counts), collapse = ", "))
}

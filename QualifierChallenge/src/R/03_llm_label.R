# 03_llm_label.R — label the candidate set with a free local model (Ollama).
#
# Each opportunity is labeled once from its abstract plus a deterministic excerpt of
# its full announcement (NOFO). The model must return JSON matching a fixed schema,
# at temperature 0 with a fixed seed. Every response is cached to
# data/cache/llm/label/<sha256>.json, keyed by model digest + prompt version + the
# exact prompt, so a re-render never re-queries and never changes a label.
#
# Requires 00_config.R, 01_load_clean.R, 01a (enrichment), 01b (priorities).
# Run standalone (slow on first run, ~20-30 s per opportunity):
#   Rscript src/R/03_llm_label.R

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(purrr); library(tibble)
  library(httr2); library(jsonlite); library(digest)
})

LABEL_LEVELS <- c("strong", "partial", "none")

DIVISIONS <- c(
  "DHHS: Aging", "DHHS: Child and Family Well-Being", "DHHS: Child Development and Early Education",
  "DHHS: Employment and Independence for People with Disabilities", "DHHS: Health Benefits (NC Medicaid)",
  "DHHS: Health Service Regulation", "DHHS: Mental Health, Developmental Disabilities and Substance Use Services",
  "DHHS: Public Health", "DHHS: Services for the Blind", "DHHS: Services for the Deaf and Hard of Hearing",
  "DHHS: Social Services", "DHHS: State Operated Healthcare Facilities", "DHHS: Office of Rural Health",
  "DMVA: State Veterans Homes", "DMVA: Veterans Services", "DMVA: State Veterans Cemeteries",
  "DMVA: Military Affairs", "Other state agency", "none")

# ---- Which opportunities get labeled ------------------------------------------------

# The candidate pool: state-eligible, not NIH, open at the pull date or forecasted,
# plus VA-issued opportunities. The 60-row hand-label sample was drawn from this pool.
label_pool <- function(g) {
  g |> filter(is_nofo_candidate(g) | (state_eligible & is_va))
}

# What actually gets labeled: pool members still open on the tool's default reference
# date (or forecasted, or with no deadline), plus every hand-label and VA opportunity.
# Items that closed before the reference date are hidden by the tool, so they keep
# rule-based labels only.
label_set <- function(g) {
  pool <- label_pool(g)
  hl_path <- file.path(DIR_MANUAL, "handlabels_60_template.csv")
  hl <- if (file.exists(hl_path)) readr::read_csv(hl_path, show_col_types = FALSE)$opportunity_number else character()
  pool |> filter(status_group == "Forecasted" | is.na(close_date) | close_date >= REF_DATE_DEFAULT |
                   opportunity_number %in% hl | is_va)
}

# ---- Prompt pieces --------------------------------------------------------------------

CAPABILITY_DEFINITIONS <- c(
  clinical_service_delivery = "delivering medical or clinical care to patients",
  behavioral_health_delivery = "delivering mental health, crisis, or substance use treatment services",
  long_term_care_operation = "operating nursing homes or other long-term care facilities",
  public_health_surveillance = "disease surveillance, epidemiology, case reporting",
  data_systems_interoperability = "building or integrating data systems, health IT, data exchange",
  research_and_rigorous_evaluation = "conducting research or a rigorous (e.g. randomized or quasi-experimental) evaluation",
  housing_stock_or_assistance = "providing housing units, rental assistance, or shelter",
  transportation_services = "providing transportation to people",
  workforce_training_credentialing = "training, credentialing, or building a workforce pipeline",
  emergency_management = "emergency preparedness, response, disaster recovery, hazard mitigation",
  benefits_eligibility_administration = "determining eligibility for or enrolling people in public benefits",
  capital_construction = "construction, renovation, or acquiring buildings or land",
  laboratory_services = "operating laboratory testing",
  subrecipient_network_management = "passing funds to and monitoring subrecipients (subawards, subgrants)"
)

nofo_excerpt <- function(nofo_text) {
  if (is.na(nofo_text) || !nzchar(nofo_text)) return(NA_character_)
  t <- str_squish(nofo_text)
  head <- str_sub(t, 1, LLM_NOFO_HEAD_CHARS)
  sents <- unlist(str_split(str_sub(t, LLM_NOFO_HEAD_CHARS + 1), "(?<=[.;])\\s+"))
  key_rx <- regex(paste0("cost[- ]shar|\\bmatch(ing)? (fund|requirement)|non-federal share|sub-?award|",
                         "sub-?recipient|evaluation|construction|renovat|governor|designat|",
                         "continuation|renewal|previously funded|current(ly)? funded"), ignore_case = TRUE)
  keep <- sents[str_detect(sents, key_rx) & nchar(sents) < 600]
  keep <- keep[!duplicated(keep)]
  key <- str_sub(paste(keep, collapse = " "), 1, LLM_NOFO_KEY_CHARS)
  paste0(head, "\n[...]\n", key)
}

plan_rows_text <- function(priorities, agency) {
  p <- priorities |> filter(agency == !!agency, level != "strategy")
  paste0("- ", p$priority_id, ": ", p$text, collapse = "\n")
}

# The prompt is built fixed-part-first: instructions, definitions and both plans are
# identical for every opportunity, so Ollama can reuse their processing between calls
# (prompt-prefix caching). Only the opportunity block at the end changes.
prompt_prefix <- function(priorities) {
  paste0(
"You label one federal funding opportunity for a grant writer inside a North Carolina state agency.
Use only the text below. If the text does not say something, answer false or \"none\" rather than guessing.
For each evidence field, copy a short phrase (under 25 words) verbatim from the OPPORTUNITY, ABSTRACT, ELIGIBILITY NOTES or FULL ANNOUNCEMENT EXCERPT sections, never from DEFINITIONS or the plans. Use \"\" if there is none.
For each alignment rationale, write one short sentence (under 30 words) in your own words naming what in the opportunity connects to the plan row.

DEFINITIONS
administrable_by_state_agency: could a North Carolina state health, human services, or veterans agency realistically be the lead applicant and run this program in North Carolina? A state agency is a public entity and a domestic government entity, so eligibility such as \"any public or private entity\", \"public or private nonprofit entities\", \"domestic public entities\", \"state governments\", or \"state and local health departments\" includes it. Answer true unless one of these applies:
- the eligibility text excludes state governments (for example only tribes, only universities, only named or invited applicants, or states only as subrecipients);
- the work happens outside the United States;
- the award funds research by an investigator (for example R01, U01, P50, clinical trials, research centers or networks) rather than delivering or improving a program;
- the work is a function health, human services, or veterans agencies do not perform (for example law enforcement, wildland fire operations, mine cleanup, economic development, arts, agriculture).
required_capabilities: pick every capability the funded work requires the applicant to deliver:
", paste0("- ", names(CAPABILITY_DEFINITIONS), ": ", CAPABILITY_DEFINITIONS, collapse = "\n"), "
program_domain (one; use \"none\" for anything that is not a health or human services program serving people in the United States, such as international programs, law enforcement, fire or land management, environmental cleanup, or economic development):
", paste0("- ", names(DOMAINS), ": ", DOMAINS, collapse = "\n"), "
- none: outside all eight domains
target_population (one): who the money ultimately serves:
", paste0("- ", names(POPULATIONS), ": ", POPULATIONS, collapse = "\n"), "
match_required: true if the text says the applicant must contribute non-federal funds, cost share, or matching funds, even without a percentage.
evaluation_required: true only if the applicant must conduct or pay for a formal evaluation of its own program (an evaluation plan, an independent evaluator, or a named evaluation design). Routine performance reporting or data collection is not an evaluation.
owning_division: the one unit most likely to own the application, from this list:
", paste0("- ", DIVISIONS, collapse = "\n"), "
alignment levels (be strict; most federal opportunities are \"none\" for any one agency):
- strong: the money would directly fund work that a specific listed objective describes, carried out in North Carolina by that agency or its NC partners.
- partial: the same program area as a listed objective and plausibly fundable for North Carolina work, but aimed at a different part of it.
- none: everything else, including work outside the United States, federal-agency internal work, research-only awards, programs outside that agency's field, and any link that rests only on general words such as \"capacity\", \"partners\", \"equity\", \"disparities\", \"access\", or \"resilience\".
If you are unsure between two levels, choose the lower one.
Judge alignment on the program's content alone, separately from administrable_by_state_agency: a program the agency could not lead can still be aligned with its plan.

NC DHHS STRATEGIC PLAN 2023-2025 (goals, objectives, priority questions)
", plan_rows_text(priorities, "DHHS"), "

NC DMVA STRATEGIC PLAN 2025-2029 (goals, objectives, priority questions)
", plan_rows_text(priorities, "DMVA"), "

THE OPPORTUNITY TO LABEL FOLLOWS.

")
}

build_prompt <- function(r, nofo, priorities, prefix = prompt_prefix(priorities)) {
  paste0(prefix,
"OPPORTUNITY
Number: ", r$opportunity_number, "
Title: ", r$opportunity_title, "
Issuing agency: ", r$agency_name, " (", r$agency_code, ")
Funding instrument: ", paste(r$instrument_list[[1]], collapse = ", "), "
Eligible applicant types: ", paste(r$applicant_type_list[[1]], collapse = ", "), "

ABSTRACT
", str_sub(r$summary_text, 1, LLM_ABSTRACT_CHARS), "

ELIGIBILITY NOTES
", coalesce(str_sub(r$eligibility_text, 1, 800), "(none)"), "

FULL ANNOUNCEMENT EXCERPT
", coalesce(nofo, "(not available)"), "

Return JSON only.")
}

label_schema <- function(priorities) {
  align <- function(agency) list(
    type = "object",
    properties = list(
      level = list(type = "string", enum = LABEL_LEVELS),
      plan_row = list(type = "string",
                      enum = c(priorities$priority_id[priorities$agency == agency], "none")),
      rationale = list(type = "string")),
    required = c("level", "plan_row", "rationale"))
  list(
    type = "object",
    properties = list(
      administrable_by_state_agency = list(type = "boolean"),
      administrable_evidence = list(type = "string"),
      program_domain = list(type = "string", enum = c(names(DOMAINS), "none")),
      owning_division = list(type = "string", enum = DIVISIONS),
      required_capabilities = list(type = "array", items = list(type = "string", enum = CAPABILITIES)),
      requires_subrecipient_network = list(type = "boolean"),
      evaluation_required = list(type = "boolean"),
      is_capital_project = list(type = "boolean"),
      needs_formal_designation = list(type = "boolean"),
      is_renewal = list(type = "boolean"),
      match_required = list(type = "boolean"),
      match_pct_stated = list(type = "number"),
      match_evidence = list(type = "string"),
      target_population = list(type = "string", enum = names(POPULATIONS)),
      alignment_dhhs = align("DHHS"),
      alignment_dmva = align("DMVA")),
    required = c("administrable_by_state_agency", "administrable_evidence", "program_domain",
                 "owning_division", "required_capabilities", "requires_subrecipient_network",
                 "evaluation_required", "is_capital_project", "needs_formal_designation",
                 "is_renewal", "match_required", "match_pct_stated", "match_evidence", "target_population",
                 "alignment_dhhs", "alignment_dmva"))
}

# ---- Model call, cached by content hash ----------------------------------------------------

model_digest <- function(model = LLM_LABEL_MODEL) {
  tags <- request(paste0(OLLAMA_URL, "/api/tags")) |> req_perform() |> resp_body_json()
  hit <- keep(tags$models, ~ .x$name == model)
  if (length(hit) == 0) stop("Model not installed in Ollama: ", model)
  hit[[1]]$digest
}

label_cache_path <- function(key) file.path(DIR_CACHE_LLM, "label", paste0(key, ".json"))

label_key <- function(prompt, schema, digest_id) {
  digest(paste(LLM_LABEL_MODEL, digest_id, LLM_PROMPT_VERSION, prompt,
               toJSON(schema, auto_unbox = TRUE), sep = "\u241f"),
         algo = "sha256", serialize = FALSE)
}

label_request <- function(prompt, schema) {
  request(paste0(OLLAMA_URL, "/api/generate")) |>
    req_body_json(list(model = LLM_LABEL_MODEL, prompt = prompt, format = schema, stream = FALSE,
                       options = list(temperature = LLM_TEMPERATURE, seed = SEED, num_ctx = LLM_NUM_CTX))) |>
    req_timeout(1800)
}

write_label <- function(resp, path, digest_id) {
  out <- list(
    label = fromJSON(resp$response, simplifyVector = FALSE),
    meta = list(model = LLM_LABEL_MODEL, model_digest = digest_id, prompt_version = LLM_PROMPT_VERSION,
                created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                prompt_tokens = resp$prompt_eval_count, output_tokens = resp$eval_count,
                seconds = round(resp$total_duration / 1e9, 1)))
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(toJSON(out, auto_unbox = TRUE, pretty = TRUE, digits = NA, null = "null"), path)
  out
}

# Sends every uncached prompt to Ollama, LLM_PARALLEL at a time, caching each result as
# soon as its batch returns. Ollama must be started with OLLAMA_NUM_PARALLEL >= LLM_PARALLEL
# for the requests to run concurrently. Results do not depend on batch order.
label_uncached <- function(prompts, schema, digest_id) {
  paths <- map_chr(prompts, ~ label_cache_path(label_key(.x, schema, digest_id)))
  todo <- which(!file.exists(paths))
  if (!length(todo)) return(invisible(paths))
  message("Model calls needed: ", length(todo), " (", LLM_PARALLEL, " at a time)")
  batches <- split(todo, ceiling(seq_along(todo) / LLM_PARALLEL))
  t0 <- Sys.time()
  for (b in seq_along(batches)) {
    idx <- batches[[b]]
    resps <- req_perform_parallel(map(prompts[idx], label_request, schema = schema),
                                  on_error = "continue", progress = FALSE)
    walk2(resps, idx, function(r, k) {
      if (inherits(r, "httr2_response")) {
        tryCatch(write_label(resp_body_json(r), paths[k], digest_id),
                 error = function(e) message("  bad response for item ", k, ": ", conditionMessage(e)))
      } else message("  request failed for item ", k, ": ", conditionMessage(r))
    })
    done <- sum(lengths(batches[seq_len(b)]))
    rate <- as.numeric(difftime(Sys.time(), t0, units = "secs")) / done
    message(sprintf("  %d/%d new labels, %.1f s each, about %.0f min left", done, length(todo), rate,
                    rate * (length(todo) - done) / 60))
  }
  invisible(paths)
}

# ---- Flatten to a table ---------------------------------------------------------------------

flatten_label <- function(number, x) {
  if (is.null(x)) return(tibble(opportunity_number = number, labeled = FALSE))
  l <- x$label
  tibble(
    opportunity_number = number, labeled = TRUE,
    llm_administrable = isTRUE(l$administrable_by_state_agency),
    llm_administrable_evidence = l$administrable_evidence %||% "",
    llm_domain = l$program_domain %||% NA_character_,
    llm_division = l$owning_division %||% NA_character_,
    llm_capabilities = list(unique(unlist(l$required_capabilities))),
    llm_subrecipient = isTRUE(l$requires_subrecipient_network),
    llm_evaluation = isTRUE(l$evaluation_required),
    llm_capital = isTRUE(l$is_capital_project),
    llm_designation = isTRUE(l$needs_formal_designation),
    llm_renewal = isTRUE(l$is_renewal),
    llm_match_required = isTRUE(l$match_required),
    llm_match_pct = { v <- as.numeric(l$match_pct_stated %||% NA); if (!is.na(v) && v > 0 && v <= 100) v else NA_real_ },
    llm_match_evidence = l$match_evidence %||% "",
    llm_population = l$target_population %||% NA_character_,
    llm_align_dhhs = l$alignment_dhhs$level %||% NA_character_,
    llm_align_dhhs_row = l$alignment_dhhs$plan_row %||% NA_character_,
    llm_align_dhhs_why = l$alignment_dhhs$rationale %||% "",
    llm_align_dmva = l$alignment_dmva$level %||% NA_character_,
    llm_align_dmva_row = l$alignment_dmva$plan_row %||% NA_character_,
    llm_align_dmva_why = l$alignment_dmva$rationale %||% "",
    llm_seconds = x$meta$seconds %||% NA_real_,
    llm_model = x$meta$model, llm_model_digest = x$meta$model_digest
  )
}

run_labeling <- function(g, enrich, priorities = alignable_priorities(), cached_only = FALSE,
                         limit = Inf, targets = label_set(g)) {
  set.seed(SEED)
  if (is.finite(limit)) targets <- head(targets, limit)
  nofo <- enrich$nofo |> select(opportunity_number, nofo_text)
  targets <- targets |> left_join(nofo, by = "opportunity_number")
  schema <- label_schema(priorities)
  prefix <- prompt_prefix(priorities)
  prompts <- map_chr(seq_len(nrow(targets)), function(i)
    build_prompt(targets[i, ], nofo_excerpt(targets$nofo_text[i]), priorities, prefix))
  digest_id <- if (cached_only) {
    # The digest is recorded in every cached label; reuse it without contacting Ollama.
    files <- list.files(file.path(DIR_CACHE_LLM, "label"), full.names = TRUE)
    if (length(files) == 0) stop("No cached labels and cached_only = TRUE")
    fromJSON(files[1])$meta$model_digest
  } else model_digest()
  message("Labeling ", nrow(targets), " opportunities with ", LLM_LABEL_MODEL, " (prompt ", LLM_PROMPT_VERSION, ")",
          if (cached_only) ", cache only" else "")
  if (!cached_only) label_uncached(prompts, schema, digest_id)
  map_dfr(seq_len(nrow(targets)), function(i) {
    path <- label_cache_path(label_key(prompts[i], schema, digest_id))
    res <- if (file.exists(path)) fromJSON(path, simplifyVector = FALSE) else NULL
    flatten_label(targets$opportunity_number[i], res) |> mutate(has_nofo = !is.na(targets$nofo_text[i]))
  })
}

# ---- Standalone run ----------------------------------------------------------------------------
if (sys.nframe() == 0L) {
  here::i_am("src/R/03_llm_label.R")
  source(here::here("src", "R", "00_config.R"))
  source(here::here("src", "R", "01_load_clean.R"))
  source(here::here("src", "R", "01a_grantsgov_enrich.R"))
  source(here::here("src", "R", "01b_alignment.R"))
  args <- commandArgs(trailingOnly = TRUE)
  limit <- if (length(args)) as.numeric(args[1]) else Inf
  enrich <- readRDS(file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))
  labels <- run_labeling(grants, enrich, limit = limit)
  saveRDS(labels, file.path(DIR_PROCESSED, "llm_labels.rds"))
  message("Labeled: ", sum(labels$labeled), " of ", nrow(labels),
          "; median seconds per call: ", median(labels$llm_seconds, na.rm = TRUE))
}

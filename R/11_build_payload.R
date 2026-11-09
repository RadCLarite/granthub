# 11_build_payload.R: items.csv + ranking.csv -> data/processed/payload.json (contract in
# saturday/03_contract.md). Run 10_run_ranking.R first.
#
# rows per agency, three groups:
#   Top 10   posted and notice items that pass the filters, best first: rank 1..TOP10_N, in_top10 TRUE
#   Coming up forecasted items that pass the filters: rank 1..COMING_UP_N within forecasts, in_top10 FALSE
#   Hidden   the HIDDEN_N best-fitting items the eligibility filter hides (eligibility "no", rank null),
#            so the tool can show its count and toggle. agencies[].n_hidden_ineligible is the full count
#            (an addition to the contract).
# signature_tier comes from cost share and award size (signature_tier() in helpers_rank.R); tier_reason says why.
# rank_note (additive) is one plain sentence on how the fit score was reached. Neither enters fit or rank.
# map_note (additive field) says why a hand-mapped program was lifted; null otherwise.
# Unknown values are null, never 0. nc_won_before is shown only; it never enters fit or rank.
# Run: Rscript R/11_build_payload.R

here::i_am("R/11_build_payload.R")
source(here::here("R", "00_config.R"))
source(here::here("R", "helpers_rank.R"))
suppressPackageStartupMessages(library(jsonlite))

stop_if_toy(CRITERIA_FILE)
items_file <- file.path(DIR_PROCESSED, "items.csv")
if (!file.exists(items_file) || !file.exists(RANKING_CSV)) stop("Run R/10_run_ranking.R first.", call. = FALSE)
chr <- cols(.default = col_character())
items <- read_csv(items_file, show_col_types = FALSE, col_types = chr)
ranking <- read_csv(RANKING_CSV, show_col_types = FALSE, col_types = chr)
inp <- load_rank_inputs(AS_OF_DATE)   # same as-of date as 10_run_ranking.R
opps <- inp$opps; amap <- inp$amap
# items.csv must come from the same AS_OF_DATE (10_run_ranking.R); a mismatch would mix two clocks in one payload.
dl <- as.integer(items$days_left); dl0 <- opps$days_left[match(items$opp_id, opps$opp_id)]
if (!identical(is.na(dl), is.na(dl0)) || !all(dl == dl0, na.rm = TRUE))
  stop("items.csv was built for a different AS_OF_DATE than ", format(AS_OF_DATE), ". Run R/10_run_ranking.R with the same AS_OF_DATE first.", call. = FALSE)

# ---- agencies -------------------------------------------------------------------------
active <- filter(amap, is.na(fold_into), is.na(drop_reason))
stopifnot(nrow(active) == 32, setequal(active$agency_id, unique(items$agency_id)))
stale <- read_csv(GOALS_FILE, show_col_types = FALSE, col_types = chr) |>
  group_by(plan_file) |> summarise(stale = any(plan_stale == "yes"), .groups = "drop")
# Expired = posted or notice with a close date before AS_OF_DATE. Expired rows never reach the payload (Top 10, hidden
# examples or counts), so each agency's Top 10 refills from its next-ranked open grants. Forecasts are not expired here.
items$expired <- items$status != "forecasted" & !is.na(items$days_left) & as.integer(items$days_left) < 0L
ranking <- ranking[!ranking$id %in% items$id[items$expired], ]
live <- items[!items$expired, ]
message("As of ", format(AS_OF_DATE), ": ", sum(items$expired[!duplicated(items$opp_id)]), " expired opportunities left out of the payload")
n_hidden <- table(live$agency_id[live$eligibility == "no"])
agencies <- lapply(seq_len(nrow(active)), function(i) {
  a <- active[i, ]
  folded <- filter(amap, fold_into == a$agency_id)
  files <- c(a$plan_file, folded$plan_file)
  list(agency_id = a$agency_id, agency_name = a$agency_name, plan_files = I(files),
       plan_stale = any(stale$stale[stale$plan_file %in% files]),
       plan_thin = FALSE,                    # set below from the goal count
       folded_from = I(folded$agency_name),
       n_hidden_ineligible = as.integer(n_hidden[a$agency_id] %||% 0L))
})

# ---- rows -----------------------------------------------------------------------------
best_first <- function(d, col) d[order(-as.numeric(d[[col]]), d$opp_id, method = "radix"), ]
pick_rows <- function(a) {
  it <- live[live$agency_id == a, ]
  rk <- ranking[ranking$agency_id == a, ]
  rk$opp_id <- sub("^[^:]*:", "", rk$id)
  rk <- merge(rk, it[, c("id", "status")], by = "id")
  open <- best_first(rk[rk$status != "forecasted", ], "total") |> head(TOP10_N)
  soon <- best_first(rk[rk$status == "forecasted", ], "total") |> head(COMING_UP_N)
  hid <- best_first(it[it$eligibility == "no", ], "fit") |> head(HIDDEN_N)
  bind_rows(
    transmute(open, agency_id, opp_id, rank = seq_len(nrow(open)), in_top10 = TRUE),
    transmute(soon, agency_id, opp_id, rank = seq_len(nrow(soon)), in_top10 = FALSE),
    transmute(hid, agency_id, opp_id, rank = NA_integer_, in_top10 = FALSE))
}
sel <- bind_rows(lapply(active$agency_id, pick_rows))
sel$rank <- as.integer(sel$rank)
n_open <- table(live$agency_id[live$status != "forecasted" & live$eligibility != "no"])

o <- opps[, c("opp_id", "summary", "cfda_list", "url", "nc_won_before")]
# Context for the tool's money, odds and effort lines (shown only; never enters fit, rank, eligibility or tier).
ctx <- opps |> transmute(opp_id, funder = na_if(clean_text(agency), ""),
  award_floor_ctx = suppressWarnings(as.numeric(award_floor)), est_total_funding = suppressWarnings(as.numeric(est_total_funding)),
  n_awards = suppressWarnings(as.integer(n_awards)), cost_sharing_ctx = na_if(cost_sharing, ""),
  applicant_types_ctx = na_if(applicant_types_named, ""), need_type = na_if(funding_activity, ""))
ctx$award_floor_ctx[!is.na(ctx$award_floor_ctx) & ctx$award_floor_ctx <= 0] <- NA
ctx$est_total_funding[!is.na(ctx$est_total_funding) & ctx$est_total_funding <= 0] <- NA
ctx$n_awards[!is.na(ctx$n_awards) & ctx$n_awards <= 0] <- NA
o <- left_join(o, ctx, by = "opp_id")

# Track record and federal program budget (shown only; never enter fit, rank, eligibility or tier).
# Track record: USAspending awards to NC recipients by program (nc_awards_by_cfda.csv), linked to our agencies through
# the hand-checked recipient map (agency_award_map.csv, confirmed rows only). Federal budget: SAM.gov obligations (05e).
aw <- read_csv(file.path(DIR_PROCESSED, "nc_awards_by_cfda.csv"), show_col_types = FALSE,
               col_types = cols(cfda = col_character(), recipient = col_character(), .default = col_guess()))
amap_aw <- read_csv(file.path(DIR_MANUAL, "agency_award_map.csv"), show_col_types = FALSE, col_types = cols(.default = col_character())) |>
  filter(certainty == "confirmed", !is.na(agency_id), agency_id != "")
aw <- left_join(aw, distinct(amap_aw[, c("recipient", "agency_id")]), by = "recipient")
fob_file <- file.path(DIR_PROCESSED, "federal_obligations.csv")
fob <- if (file.exists(fob_file)) read_csv(fob_file, show_col_types = FALSE, col_types = cols(cfda = col_character(), program = col_character(), .default = col_double())) else NULL
cfdas_of <- function(x) { v <- trimws(unlist(strsplit(ifelse(is.na(x), "", x), "|", fixed = TRUE))); v[v != ""] }
track_one <- function(ag, cf) {
  c0 <- cfdas_of(cf); mine <- aw[!is.na(aw$agency_id) & aw$agency_id == ag, ]
  hit <- mine[mine$cfda %in% c0, ]; other <- aw[aw$cfda %in% c0 & (is.na(aw$agency_id) | aw$agency_id != ag), ]
  dept <- unique(substr(c0, 1, 2))
  top_other <- if (nrow(other)) other$recipient[which.max(other$n_awards)] else NA_character_
  f <- if (!is.null(fob)) fob[fob$cfda %in% c0, ] else NULL
  sumna <- function(x) if (length(x) && any(!is.na(x))) sum(x, na.rm = TRUE) else NA_real_
  list(ag_won_n = if (nrow(hit)) sum(hit$n_awards) else 0L, ag_won_usd = if (nrow(hit)) round(sum(hit$total_obligated)) else NA_real_,
       ag_last_fy = if (nrow(hit)) max(hit$last_fy) else NA_integer_,
       nc_other_n = if (nrow(other)) sum(other$n_awards) else 0L, nc_other_top = top_other,
       ag_dept_programs = length(unique(mine$cfda[substr(mine$cfda, 1, 2) %in% dept & !(mine$cfda %in% c0)])),
       fed_fy24 = sumna(f$fy24), fed_fy25 = sumna(f$fy25), fed_fy26 = sumna(f$fy26))
}
rows <- sel |>
  left_join(items, by = c("agency_id", "opp_id")) |>
  left_join(o, by = "opp_id") |>
  (\(d) bind_cols(d, signature_tier(d$cost_sharing, d$award_ceiling)))() |>
  mutate(rank_note = rank_note(fit, rank, in_top10, map_note, as.logical(geo_other), n_open = as.integer(n_open[agency_id]))) |>
  arrange(agency_id, is.na(rank), !in_top10, rank, opp_id) |>
  transmute(
    agency_id, opp_id, opp_number, title = clean_text(title), status,
    close_date = na_if(close_date, ""),
    # days_left counts from AS_OF_DATE, the same date that stamps data_as_of and that the tool and job.R count from.
    days_left = ifelse(is.na(close_date) | close_date == "", NA_integer_, as.integer(as.Date(close_date) - AS_OF_DATE)),
    date_note = na_if(date_note, ""),
    fit_score = round(as.numeric(fit), 4), rank, in_top10,
    eligibility, elig_source = na_if(elig_source, ""), elig_quote = na_if(clean_text(elig_quote), ""),
    reader_label = NA_character_, reader_quote = NA_character_,
    map_note = na_if(map_note, ""), goal_id = na_if(goal_id, ""), goal_snippet = na_if(clean_text(goal_snippet), ""),
    opp_snippet = str_sub(clean_text(summary), 1, SNIPPET_CHARS),
    cfda_list, award_ceiling = as.numeric(award_ceiling),
    signature_tier, tier_source, tier_reason, rank_note,
    nc_won_before = as.logical(nc_won_before), url,
    funder, award_floor = award_floor_ctx, est_total_funding, n_awards, cost_sharing = cost_sharing_ctx, applicant_types = applicant_types_ctx, need_type)
# Who it reaches (display only): population groups by keyword rule on title then summary, each with its quote.
rows$reach <- tag_groups(rows$title, clean_text(o$summary[match(rows$opp_id, o$opp_id)]))
message("Reach: ", sum(lengths(lapply(rows$reach, `[[`, "id")) > 0), " of ", nrow(rows), " rows tagged with a population group")
tr <- bind_rows(Map(function(ag, cf) as_tibble(track_one(ag, cf)), rows$agency_id, rows$cfda_list))
rows <- bind_cols(rows, tr)
message("Track record: ", sum(rows$ag_won_n > 0), " rows where the agency won the program before; federal budget on ", sum(!is.na(rows$fed_fy25)), " rows")

# Notice reader (30_notice_reader.R, advisory): fill reader_label and reader_quote when its output exists.
# Labels without a verified quote are already "unclear" there; skipped items stay null. Never changes rank or tier.
if (file.exists(NOTICE_READER_CSV)) {
  rd <- read_csv(NOTICE_READER_CSV, show_col_types = FALSE, col_types = chr) |> distinct(opp_id, .keep_all = TRUE)
  i <- match(rows$opp_id, rd$opp_id)
  rows$reader_label <- na_if(rd$reader_label[i], "")
  rows$reader_quote <- na_if(clean_text(rd$reader_quote[i]), "")
  message("Notice reader: ", sum(!is.na(rows$reader_label)), " rows labeled from ", basename(NOTICE_READER_CSV))
}

# Swipe-card summary (31_swipe_summary.R, advisory): plain-language ai_summary with a verified source quote.
# Rows without a verified quote stay NA and the tool falls back to the first-sentence snippet. Never changes rank or tier.
SWIPE_SUMMARY_CSV <- here::here("data", "processed", "swipe_summary.csv")
if (file.exists(SWIPE_SUMMARY_CSV)) {
  sw <- read_csv(SWIPE_SUMMARY_CSV, show_col_types = FALSE, col_types = cols(.default = "c")) |> filter(quote_ok %in% c("TRUE", "True", "true")) |> distinct(opp_id, .keep_all = TRUE)
  rows$ai_summary <- na_if(sw$ai_summary[match(rows$opp_id, sw$opp_id)], "")
  rows$ai_quote   <- na_if(sw$ai_quote[match(rows$opp_id, sw$opp_id)], "")
  message("Swipe summaries: ", sum(!is.na(rows$ai_summary)), " rows with an AI summary")
}

# Closing soon: open Top 10 rows with CLOSING_SOON_DAYS or fewer days left (the tool's panel reads days_left itself;
# this count lets it show a badge without scanning).
soon <- rows[rows$in_top10 & !is.na(rows$days_left) & rows$days_left >= 0 & rows$days_left <= CLOSING_SOON_DAYS, ]
for (i in seq_along(agencies)) agencies[[i]]$n_closing_soon <- sum(soon$agency_id == agencies[[i]]$agency_id)
# State General Fund base budget per agency (05f_agency_budget.R, OSBM); context only. NA when the agency has no General Fund line.
bud_file <- file.path(DIR_PROCESSED, "agency_budget.csv")
if (file.exists(bud_file)) {
  bud <- read_csv(bud_file, show_col_types = FALSE, col_types = cols(agency_id = col_character(), gf_base_fy2526 = col_double(), .default = col_character()))
  for (i in seq_along(agencies)) { j <- match(agencies[[i]]$agency_id, bud$agency_id); agencies[[i]]$gf_base_fy2526 <- if (is.na(j)) NA_real_ else bud$gf_base_fy2526[j] }
}

# goals[] (additive, for the match board and the alignment view): each active agency's own plan goals.
# Folded plans (State Board of Education) belong to the agency they fold into; duplicates and dropped plans are skipped.
goal_src <- read_csv(GOALS_FILE, show_col_types = FALSE, col_types = chr)
plan_owner <- amap |> transmute(plan_file, owner = ifelse(is.na(fold_into), agency_id, fold_into)) |>
  filter(!is.na(plan_file), is.na(amap$drop_reason[match(plan_file, amap$plan_file)]))
goals <- goal_src |>
  filter(is.na(duplicate_of_row) | duplicate_of_row == "") |>
  inner_join(plan_owner, by = "plan_file") |>
  transmute(agency_id = owner, goal_id, goal_text = str_sub(clean_text(ifelse(is.na(goal_statement) | goal_statement == "", goal_text_exact, goal_statement)), 1, 240)) |>
  filter(agency_id %in% active$agency_id, !is.na(goal_text), goal_text != "") |>
  distinct(agency_id, goal_id, .keep_all = TRUE)

# plan_thin: the agency's plan text (all its plan files, folded plans included) is small, so the keyword fit rests on little text.
plan_text_dir <- here::here("data", "processed", "agency_plan_text", "all")
plan_bytes <- function(files) sum(file.size(file.path(plan_text_dir, paste0(sub("[.]pdf$", "", files[!is.na(files)]), ".txt"))), na.rm = TRUE)
for (i in seq_along(agencies)) agencies[[i]]$plan_thin <- plan_bytes(agencies[[i]]$plan_files) < PLAN_THIN_MIN_BYTES

# Qualifier datasets carried into the tool: county outlines + need indicators (need map), and the
# hand-built capability table for DHHS and DMVA (who controls what; other agencies are absent).
shapes <- read_csv(COUNTY_SHAPES_FILE, show_col_types = FALSE, col_types = chr)
need   <- read_csv(COUNTY_NEED_FILE, show_col_types = FALSE, col_types = cols(.default = col_character(), value = col_double(), percentile = col_double()))
county_need <- list(
  indicators = need |> distinct(indicator, label) |> arrange(label) |> transmute(id = indicator, label),
  values = need |> arrange(indicator, fips) |> transmute(fips, id = indicator, v = round(value, 3), pct = round(percentile, 3)))
capabilities <- read_csv(CAPABILITIES_FILE, show_col_types = FALSE, col_types = chr) |>
  mutate(agency_id = unname(CAPABILITY_AGENCY_IDS[agency])) |>
  filter(!is.na(agency_id), agency_id %in% active$agency_id) |>
  transmute(agency_id, capability_id, label = capability_label, control_level, notes, source_url, to_resolve)
# Where each population lives (from the qualifier payload): county and congressional-district counts, county rurality.
reach <- NULL
if (file.exists(QUALIFIER_PAYLOAD)) {
  qp <- fromJSON(QUALIFIER_PAYLOAD, simplifyVector = FALSE)
  keep <- intersect(names(GROUP_RULES), names(qp$populations))
  reach <- c(list(groups = unname(lapply(qp$populations[keep], function(g) g[c("id", "label", "n", "source", "county", "district")]))),
             qp$community[c("county_pop", "county_rurality", "rurality_rule", "district_names", "district_note", "caveat")])
}
evidence <- fromJSON(here::here("data", "manual", "evidence.json"), simplifyVector = FALSE)
evidence[["_note"]] <- NULL

# Slim the file (no change to what the tool shows):
#  * rank_note and map_note are written for the audit trail but the tool never reads them: dropped.
#  * Opportunity-level fields repeat on every row of an opp_id that sits under several agencies. Stored once in
#    payload$opps[[opp_id]]; the tool copies them back onto each row when it loads (matchmaker.html, "join opps").
#    The contract fields (saturday/03_contract.md, job.R need_r) stay on the rows, so job.R and the tests are unaffected.
#    Only fields identical on every row of an opp_id may move; the check below stops the build otherwise.
OPP_FIELDS <- intersect(c("tier_reason", "funder", "award_floor", "est_total_funding", "n_awards", "cost_sharing",
                          "applicant_types", "need_type", "reach", "fed_fy24", "fed_fy25", "fed_fy26", "ai_summary", "ai_quote"),
                        names(rows))
by_opp <- split(seq_len(nrow(rows)), rows$opp_id)
for (f in OPP_FIELDS) {
  same <- vapply(by_opp, function(ix) length(unique(rows[[f]][ix])) == 1L, TRUE)
  if (!all(same)) stop("opp-level field differs between agencies for the same opp_id: ", f, call. = FALSE)
}
first_ix <- vapply(by_opp, `[`, 1L, 1L)
opps_out <- lapply(first_ix, function(i) lapply(setNames(OPP_FIELDS, OPP_FIELDS), function(f) rows[[f]][[i]]))
rows <- rows[, setdiff(names(rows), c(OPP_FIELDS, "rank_note", "map_note"))]
message("Slim payload: ", length(OPP_FIELDS), " opp-level fields moved to opps (", length(opps_out), " opps for ", nrow(rows), " rows)")

payload <- list(data_as_of = PAYLOAD_AS_OF, window_days = WINDOW_DEFAULT_WEEKS * 7L,
                closing_soon_days = as.integer(CLOSING_SOON_DAYS), agencies = agencies, goals = goals,
                counties = shapes, county_need = county_need, capabilities = capabilities, reach = reach, evidence = evidence, opps = opps_out, rows = rows)
write_json(payload, PAYLOAD_JSON, auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE, digits = NA)
message("Wrote payload.json: ", length(agencies), " agencies, ", nrow(rows), " rows (",
        sum(rows$in_top10), " top 10, ", sum(!rows$in_top10 & rows$eligibility != "no"), " coming up, ",
        sum(rows$eligibility == "no"), " hidden)")

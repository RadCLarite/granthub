# 07_top_results.R — the competition's "top results list": every opportunity in Tiers 1-3
# of the tool's opening scenario (and DMVA's view), ordered by tier then impact score, each
# with a one-line rationale tied to the five match criteria:
#   1. can be the applicant  2. has the capabilities  3. enough runway
#   4. award worth the effort  5. match is survivable
# Tiers, impact and capability gaps come from src/tool/tiering.js run through V8, so the list
# is exactly what the tool shows. Output: outs/top_results.csv and outs/top_results.xlsx.

suppressPackageStartupMessages({ library(dplyr); library(purrr); library(stringr); library(jsonlite); library(tibble) })

TOP_RESULTS_MAX_TIER <- 3L

run_tiering_piles_js <- function(payload, settings) {
  ctx <- V8::v8()
  ctx$source(tiering_js_path())
  to_js <- function(x) toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
  ctx$eval(paste0("var P = ", to_js(list(opportunities = payload$opportunities,
                                           capabilities = payload$capabilities)), ";"))
  ctx$eval(paste0("var S = ", to_js(settings), ";"))
  out <- ctx$eval("JSON.stringify((function () {
      var res = Tiering.run(P, S), prof = P.capabilities.profiles[S.agency] || {}, rows = [];
      [1, 2, 3, 4].forEach(function (k) {
        res.piles[k].forEach(function (it, i) {
          rows.push({ number: it.opp.number, tier: k, rank_in_tier: i + 1,
                      impact: it.impact ? it.impact.score : null, parts: it.impact ? it.impact.parts : null,
                      tier_reason: it.tier_reason,
                      days_left: it.days_left, gaps: Tiering.capabilityGaps(it.opp, prof) });
        });
      });
      return rows;
    })())")
  fromJSON(out, simplifyVector = FALSE)
}

usd_short <- function(x) {
  if (is.null(x) || is.na(x)) return("award not stated on Grants.gov")
  if (x >= 1e6) return(paste0("~$", format(round(x / 1e6, 1), nsmall = 1), "M"))
  paste0("~$", round(x / 1e3), "K")
}

one_line_rationale <- function(row, opp, settings, tier_names) {
  applicant <- if (isTRUE(opp$screen$is_nih) || isTRUE(opp$screen$is_research_mechanism)) "research award (a university would apply)"
               else if (isTRUE(opp$screen$not_administrable)) "a partner would likely lead"
               else "state agency can apply"
  if (identical(opp$status, "forecasted")) applicant <- paste0(applicant, ", forecast (not yet posted)")
  gaps <- row$gaps
  need <- keep(gaps, ~ .x$control %in% c("partner", "none"))
  caps <- if (length(gaps) == 0) "no special capabilities detected"
          else if (length(need) == 0) "required capabilities in-house or contracted"
          else paste(map_chr(need, ~ paste0(if (.x$control == "none") "no route to " else "partner needed for ",
                                            tolower(.x$label))), collapse = "; ")
  runway <- if (is.null(row$days_left)) "no deadline stated" else paste0(row$days_left, " days to deadline")
  award <- if (is.null(opp$award_estimate_usd)) usd_short(NULL)
           else if (identical(opp$award_basis, "total_over_awards")) paste0("about ", sub("^~", "", usd_short(opp$award_estimate_usd)), " per award (estimated: total ÷ expected awards)")
           else paste0("up to ", sub("^~", "", usd_short(opp$award_estimate_usd)), " (Grants.gov ceiling)")
  match <- if (isTRUE(opp$cost_share)) paste0("cost share required", if (!is.null(opp$match_pct)) paste0(" (", opp$match_pct, "% stated)") else " (percentage not published)")
           else "no cost share"
  paste0(applicant, " · ", caps, " · ", runway, " · ", award, " · ", match,
         " → Tier ", row$tier, ": ", tier_names[[as.character(row$tier)]])
}

build_top_results <- function(payload, agency = "DHHS", settings = payload$config$opening) {
  settings$agency <- agency
  tier_names <- list("1" = "writer can act", "2" = "needs supervisor or division",
                     "3" = "needs secretary or legislature", "4" = "partner-led research")
  by_num <- setNames(payload$opportunities, map_chr(payload$opportunities, "number"))
  rows <- run_tiering_piles_js(payload, settings)
  rows <- keep(rows, ~ .x$tier <= TOP_RESULTS_MAX_TIER)
  map_dfr(rows, function(r) {
    o <- by_num[[r$number]]
    # Points each part adds to the impact score: weight x part value (0-1), shared out over the
    # parts that have a number, so the points add up to the score.
    w <- unlist(settings$impact_weights)
    known <- names(w)[map_lgl(names(w), ~ !is.null(r$parts[[.x]]) && w[[.x]] > 0)]
    pts <- function(k) if (k %in% known) round(100 * w[[k]] * r$parts[[k]] / sum(w[known]), 1) else NA_real_
    al <- o$alignment[[agency]]
    people <- o$people_est %||% NA_real_
    award <- o$award_estimate_usd %||% NA_real_
    tibble(agency = agency, tier = r$tier, rank_in_tier = r$rank_in_tier,
           impact_score = r$impact %||% NA_real_,
           plan_fit_rating = al$llm_level %||% (if (!is.null(al$pct)) paste0("text similarity, ", round(100 * al$pct), "th percentile") else NA_character_),
           plan_fit_points = pts("alignment"),
           people_reached = people,
           population_served = if (is.null(o$target_population)) NA_character_ else payload$populations[[o$target_population]]$label %||% NA_character_,
           people_reached_points = pts("reach"),
           help_per_person_usd = if (is.na(people) || is.na(award)) NA_real_ else round(award / people, 2),
           help_per_person_points = pts("depth"),
           award_size_points = pts("award"),
           program_area = if (is.null(o$domain)) NA_character_ else DOMAINS[[o$domain]] %||% NA_character_,
           priority_weight = if (is.null(o$domain)) 0 else settings$domain_weights[[o$domain]] %||% NA_real_,
           program_priorities_points = pts("priority"),
           opportunity_number = r$number, opportunity_id = o$id %||% NA_character_,
           title = o$title, issuing_agency = o$agency_code,
           status = o$status, deadline = if (is.null(o$close_day)) NA else as.Date(o$close_day, origin = "1970-01-01"),
           estimated_award = o$award_estimate_usd %||% NA_real_,
           award_floor = o$award_floor_usd %||% NA_real_,
           award_source = switch(o$award_basis %||% "none", grantsgov_ceiling = "Grants.gov award ceiling",
                                 ceiling = "Award ceiling in the export", total_over_awards = "Estimate: total funding / expected awards",
                                 "Not stated (Grants.gov gives no total or no award count to estimate from)"),
           rationale = one_line_rationale(r, o, settings, tier_names),
           rules_that_fired = r$tier_reason, link = o$url %||% NA_character_)
  }) |> arrange(tier, rank_in_tier)
}

write_top_results <- function(tr) {
  tr <- select(tr, agency, tier, rank_in_tier, impact_score, opportunity_number, title, issuing_agency,
               status, deadline, estimated_award, rationale, rules_that_fired, link)
  csv <- file.path(DIR_OUTS, "top_results.csv"); readr::write_csv(tr, csv, na = "")
  wb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(wb, "Top results")
  openxlsx::writeData(wb, 1, tr, withFilter = TRUE)
  openxlsx::addStyle(wb, 1, openxlsx::createStyle(textDecoration = "bold", fgFill = "#D9EAF7", wrapText = TRUE),
                     rows = 1, cols = seq_along(tr), gridExpand = TRUE)
  openxlsx::addStyle(wb, 1, openxlsx::createStyle(wrapText = TRUE, valign = "top"),
                     rows = 2:(nrow(tr) + 1), cols = seq_along(tr), gridExpand = TRUE)
  openxlsx::freezePane(wb, 1, firstRow = TRUE)
  openxlsx::setColWidths(wb, 1, cols = seq_along(tr),
                         widths = c(8, 6, 8, 8, 20, 45, 16, 10, 11, 12, 70, 50, 30)[seq_along(tr)])
  xlsx <- file.path(DIR_OUTS, "top_results.xlsx"); openxlsx::saveWorkbook(wb, xlsx, overwrite = TRUE)
  c(csv, xlsx)
}

# The team's version: one tab per tier, the impact score and its five parts, Grants.gov's
# deadline (a real date) and award ceiling, and an empty rationale column for the team to write.
# Output: outs/top_results_team.xlsx
# With `rationales` (a table of agency, opportunity_number, rationale) the same workbook is written
# with the rationale column filled in: outs/top_results_with_rationale.xlsx.
write_team_sheet <- function(tr, path = file.path(DIR_OUTS, "top_results_team.xlsx"), rationales = NULL) {
  filled <- !is.null(rationales)
  cols <- c("Agency" = "agency", "Rank in tier" = "rank_in_tier", "Impact score (0-100)" = "impact_score",
            "Plan fit: labeler's rating" = "plan_fit_rating", "Plan fit: points" = "plan_fit_points",
            "People reached: NC people served" = "people_reached", "Population served" = "population_served",
            "People reached: points" = "people_reached_points",
            "Help per person: award / people ($)" = "help_per_person_usd", "Help per person: points" = "help_per_person_points",
            "Award size: points" = "award_size_points",
            "Program area" = "program_area", "Program priority weight (of 3)" = "priority_weight",
            "Program priorities: points" = "program_priorities_points",
            "Opportunity number" = "opportunity_number", "Grants.gov ID" = "grantsgov_id",
            "Simpler.Grants.gov ID" = "opportunity_id",
            "Title" = "title", "Issuing agency" = "issuing_agency", "Status" = "status",
            "Deadline (Grants.gov)" = "deadline", "Award per recipient" = "estimated_award", "Award source" = "award_source",
            "Award floor (Grants.gov)" = "award_floor", "Rationale" = "rationale", "Link" = "link")
  wb <- openxlsx::createWorkbook()
  hdr <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#E6D6A8", wrapText = TRUE, valign = "top",
                               border = "bottom", borderColour = "#C9B57E")
  wrap <- openxlsx::createStyle(wrapText = TRUE, valign = "top")
  money <- openxlsx::createStyle(numFmt = "$#,##0", valign = "top")
  date <- openxlsx::createStyle(numFmt = "mmm d, yyyy", valign = "top")
  blank <- openxlsx::createStyle(fgFill = "#FFF8E1", wrapText = TRUE, valign = "top")

  if (filled && file.exists(file.path(DIR_MANUAL, "top_results_explanation.txt"))) {
    # The team's own explanation tab (data/manual/top_results_explanation.txt): a heading line, then paragraphs.
    expl <- readLines(file.path(DIR_MANUAL, "top_results_explanation.txt"), warn = FALSE)
    expl <- expl[nzchar(trimws(expl))]
    openxlsx::addWorksheet(wb, "EXPLANATION")
    openxlsx::writeData(wb, 1, data.frame(x = expl[-1]), startRow = 2, colNames = FALSE)
    openxlsx::writeData(wb, 1, expl[1], startRow = 1)
    openxlsx::setColWidths(wb, 1, 1, 140)
    openxlsx::addStyle(wb, 1, hdr, rows = 1, cols = 1)
    openxlsx::addStyle(wb, 1, wrap, rows = seq_along(expl)[-1], cols = 1)
  } else {
    openxlsx::addWorksheet(wb, "How to fill this in")
    notes <- c(
      "One tab per tier. Each row is an opportunity in that tier in the tool's opening scenario (NC DHHS, plus NC DMVA's two Tier 3 items).",
      if (filled) "Each rationale says why the opportunity ranks where it does and what the grant funds. Our five criteria:" else "Write one line in the yellow Rationale column. Tie it to our five criteria: (1) we can be the applicant, (2) we have the capabilities or know the partner, (3) there is enough runway, (4) the award is worth the staff weeks, (5) the match is survivable at the writer's level.",
      "Deadline and award come from each opportunity's current record on Grants.gov (checked Sept 29-30, 2026). Forecast deadlines are Grants.gov's estimates. The award is Grants.gov's stated award ceiling; where it states none, the award is estimated as total program funding divided by the expected number of awards, and the Award source column says so. A blank award means Grants.gov gives neither.",
      "Impact score (0-100) orders opportunities within a tier only; it never moves anything between tiers. For each of five parts the sheet shows the actual number and the points it adds; the points add up to the score (small differences are rounding).",
      "  Plan fit: the AI labeler's rating of fit with the agency's strategic plan. Strong earns full points, partial half, none zero.",
      "  People reached: how many North Carolinians are in the population the opportunity serves (the population is named in the next column).",
      "  Help per person: the award per recipient divided by that population.",
      "  Award size: the award per recipient (shown in the Award per recipient column, with its source).",
      "  Program priorities: the writer's weight for the opportunity's program area, out of 3. The default is 1 for every area.",
      "People reached, help per person and award size earn points by how their number ranks against all the opportunities in the tool's view (about 400), not by the number alone. The biggest number gets full points; the median gets about half.",
      "With the default equal weights, each part can add at most 100 / (number of parts with a number): 20 points when all five have one. A blank part has no number, and the others share its points. People reached is blank when the population served has no NC count (people with a substance use disorder); help per person is blank when either the award or the people count is.",
      "Grants.gov ID is the number in grants.gov listing addresses; Simpler.Grants.gov ID is the code in the link, which opens the listing.")
    openxlsx::writeData(wb, 1, data.frame(`How to fill this in` = notes, check.names = FALSE))
    openxlsx::setColWidths(wb, 1, 1, 140)
    openxlsx::addStyle(wb, 1, hdr, rows = 1, cols = 1)
    openxlsx::addStyle(wb, 1, wrap, rows = 2:(length(notes) + 1), cols = 1)
  }

  tier_names <- c("1" = "Tier 1 - Writer can act", "2" = "Tier 2 - Supervisor", "3" = "Tier 3 - Secretary or legis.")
  for (k in names(tier_names)) {
    d <- tr |> filter(tier == as.integer(k)) |> arrange(agency, rank_in_tier) |> mutate(rationale = NA_character_)
    if (filled) {
      d <- d |> select(-rationale) |> left_join(rationales, by = c("agency", "opportunity_number"))
      missing <- d$opportunity_number[is.na(d$rationale)]
      if (length(missing)) stop("No rationale written for: ", paste(missing, collapse = ", "))
    }
    out <- setNames(d[unname(cols)], names(cols))
    sh <- tier_names[[k]]
    openxlsx::addWorksheet(wb, sh)
    openxlsx::writeData(wb, sh, out, withFilter = TRUE)
    n <- nrow(out) + 1
    openxlsx::addStyle(wb, sh, hdr, rows = 1, cols = seq_along(cols), gridExpand = TRUE)
    if (n > 1) {
      openxlsx::addStyle(wb, sh, wrap, rows = 2:n, cols = seq_along(cols), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, date, rows = 2:n, cols = which(names(cols) == "Deadline (Grants.gov)"), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, money, rows = 2:n, cols = which(names(cols) %in% c("Award per recipient", "Award floor (Grants.gov)")), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, openxlsx::createStyle(numFmt = "#,##0", valign = "top"), rows = 2:n,
                         cols = which(names(cols) == "People reached: NC people served"), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, openxlsx::createStyle(numFmt = "$#,##0.00", valign = "top"), rows = 2:n,
                         cols = which(names(cols) == "Help per person: award / people ($)"), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, openxlsx::createStyle(numFmt = "0.0", valign = "top", textDecoration = "bold"), rows = 2:n,
                         cols = which(grepl("points", names(cols))), gridExpand = TRUE)
      openxlsx::addStyle(wb, sh, if (filled) wrap else blank, rows = 2:n, cols = which(names(cols) == "Rationale"), gridExpand = TRUE)
      links <- out$Link; class(links) <- "hyperlink"
      openxlsx::writeData(wb, sh, x = links, startCol = which(names(cols) == "Link"), startRow = 2)
    }
    openxlsx::freezePane(wb, sh, firstActiveRow = 2, firstActiveCol = which(names(cols) == "Title") + 1)
    openxlsx::setColWidths(wb, sh, cols = seq_along(cols),
                           widths = c(8, 7, 9, 12, 8, 14, 22, 8, 12, 8, 10, 22, 9, 9, 22, 11, 20, 48, 16, 11, 13, 14, 24, 13, 55, 30))
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/07_top_results.R")
  for (f in c("00_config", "01_load_clean", "02_capabilities")) source(here::here("src", "R", paste0(f, ".R")))
  payload <- jsonlite::fromJSON(PAYLOAD_JSON, simplifyVector = FALSE)
  tr <- bind_rows(build_top_results(payload, "DHHS"), build_top_results(payload, "DMVA"))
  message("Wrote ", paste(write_top_results(tr), collapse = ", "), " (", nrow(tr), " rows)")
  ids <- readRDS(file.path(DIR_PROCESSED, "grantsgov_enrichment.rds"))$status |> select(opportunity_number, grantsgov_id = legacy_id)
  tr_ids <- left_join(tr, ids, by = "opportunity_number")
  message("Wrote ", write_team_sheet(tr_ids), " (tabs by tier, blank rationale)")
  rat <- readr::read_csv(file.path(DIR_MANUAL, "top_results_rationales.csv"), col_types = "ccc")
  message("Wrote ", write_team_sheet(tr_ids, file.path(DIR_OUTS, "top_results_with_rationale.xlsx"), rat),
          " (tabs by tier, rationale filled)")
  print(select(tr, agency, tier, impact_score, rationale) |> head(8), width = 250)
}

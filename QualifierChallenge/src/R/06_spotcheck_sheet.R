# 06_spotcheck_sheet.R — Phase 5 spot-check sheet. Lists every opportunity the tool
# places in a pile under the opening scenario (and, separately, the research-screened
# items the plan-alignment score flags "check this"), with blank verdict columns for a
# team member to fill in by reading the opportunity.
# Run after the payload is rebuilt:  Rscript src/R/06_spotcheck_sheet.R
# Output: data/manual/spotcheck_template.csv  → save filled copy as data/manual/spotcheck.csv

build_spotcheck_sheet <- function(payload) {
  opps <- payload$opportunities
  by_num <- setNames(opps, map_chr(opps, "number"))
  flat <- run_tiering_js(opps, payload$capabilities$profiles, payload$config$opening)
  piled <- flat |> filter(placement == "pile", tier <= 3) |> mutate(section = "In Tiers 1-3")
  # Research and partner-led items (Tier 4, or screened when research is hidden): only those
  # the plan-alignment score flags "check this" go to reviewers.
  rescue <- flat |> filter((placement == "pile" & tier == 4) | placement == "screened") |>
    filter(map_dbl(opportunity_number, ~ by_num[[.x]]$alignment$DHHS$pct %||% 0) >= ALIGNMENT_RESCUE_PCT) |>
    mutate(section = "Research or partner-led, flagged 'check this'")
  bind_rows(piled, rescue) |>
    mutate(o = map(opportunity_number, ~ by_num[[.x]])) |>
    transmute(
      section, opportunity_number,
      title = map_chr(o, "title"), agency = map_chr(o, "agency_code"),
      grants_gov_link = map_chr(o, ~ .x$url %||% ""),
      tool_tier = tier, tool_reason = coalesce(tier_reason, placement_why),
      required_capabilities = map_chr(o, ~ paste(unlist(.x$required_capabilities), collapse = "; ")),
      cost_share = map_lgl(o, "cost_share"),
      full_announcement_read = map_lgl(o, ~ isTRUE(.x$has_full_announcement)),
      # --- filled in by the reviewer ---------------------------------------
      verdict = "",            # right / wrong / unsure
      correct_tier = "",       # 1 / 2 / 3 / not relevant, if the verdict is wrong
      what_the_tool_missed = "",
      reviewer_initials = ""
    ) |>
    arrange(section, tool_tier)
}

# Spreadsheet version for non-technical reviewers: an instructions sheet, frozen
# header, wrapped text, and dropdowns on the verdict columns so values stay consistent.
write_spotcheck_xlsx <- function(sheet, path) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "How to fill this in")
  openxlsx::writeData(wb, 1, data.frame(Instructions = c(
    "Each row is an opportunity the tool placed in a pile (or screened out but flagged 'check this').",
    "Open the Grants.gov link, read enough to judge, and fill in the four yellow columns on the Spot-check sheet.",
    "verdict: right = the tool's tier is correct; wrong = it is not; unsure = you could not tell.",
    "correct_tier: only if the verdict is wrong. 1, 2, 3, or 'not relevant' if the agency should not pursue it at all.",
    "what_the_tool_missed: one sentence, e.g. 'needs a housing partner', 'match is 50%', 'this is a research grant'.",
    "Put your initials in reviewer_initials. Return the file to Kent (it is saved as data/manual/spotcheck.csv).")))
  openxlsx::setColWidths(wb, 1, 1, 120)
  openxlsx::addWorksheet(wb, "Spot-check")
  openxlsx::writeData(wb, 2, sheet, withFilter = TRUE)
  hdr <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#D9EAF7", wrapText = TRUE)
  openxlsx::addStyle(wb, 2, hdr, rows = 1, cols = seq_along(sheet), gridExpand = TRUE)
  openxlsx::freezePane(wb, 2, firstRow = TRUE)
  input_cols <- match(c("verdict", "correct_tier", "what_the_tool_missed", "reviewer_initials"), names(sheet))
  n <- nrow(sheet) + 1
  openxlsx::addStyle(wb, 2, openxlsx::createStyle(fgFill = "#FFF4CC", wrapText = TRUE),
                     rows = 2:n, cols = input_cols, gridExpand = TRUE)
  openxlsx::addStyle(wb, 2, openxlsx::createStyle(wrapText = TRUE, valign = "top"),
                     rows = 2:n, cols = setdiff(seq_along(sheet), input_cols), gridExpand = TRUE)
  openxlsx::dataValidation(wb, 2, cols = input_cols[1], rows = 2:n, type = "list", value = '"right,wrong,unsure"')
  openxlsx::dataValidation(wb, 2, cols = input_cols[2], rows = 2:n, type = "list", value = '"1,2,3,not relevant"')
  widths <- c(section = 22, opportunity_number = 20, title = 45, agency = 16, grants_gov_link = 30,
              tool_tier = 9, tool_reason = 60, required_capabilities = 30, cost_share = 10,
              full_announcement_read = 12, verdict = 12, correct_tier = 12, what_the_tool_missed = 40,
              reviewer_initials = 10)
  openxlsx::setColWidths(wb, 2, cols = seq_along(sheet), widths = unname(widths[names(sheet)]))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

if (sys.nframe() == 0L) {
  here::i_am("src/R/06_spotcheck_sheet.R")
  for (f in c("00_config", "01_load_clean", "02_capabilities"))
    source(here::here("src", "R", paste0(f, ".R")))
  payload <- jsonlite::fromJSON(PAYLOAD_JSON, simplifyVector = FALSE)
  sheet <- build_spotcheck_sheet(payload)
  path <- file.path(DIR_MANUAL, "spotcheck_template.csv")
  # Never overwrite a sheet a reviewer has already filled in.
  if (file.exists(path)) {
    old <- readr::read_csv(path, col_types = readr::cols(.default = "c"), show_col_types = FALSE)
    if ("verdict" %in% names(old) && any(!is.na(old$verdict) & nzchar(old$verdict))) {
      path <- file.path(DIR_MANUAL, "spotcheck_template_new.csv")
      message("spotcheck_template.csv already has verdicts; writing the new blank sheet to ", basename(path))
    }
  }
  readr::write_csv(sheet, path, na = "")
  message("Wrote ", path, ": ", nrow(sheet), " rows (", paste(names(table(sheet$section)), table(sheet$section), collapse = ", "), ")")
  message("Wrote ", write_spotcheck_xlsx(sheet, file.path(DIR_OUTS, "spotcheck_for_team.xlsx")))
}

# test_research.R: parsers and pool rules for the researcher tab (R/helpers_research.R).
# Sourced by run_tests.R, which provides check(); also runnable alone: Rscript tests/test_research.R

local({
  standalone <- !exists("check", mode = "function")
  if (standalone) {
    here::i_am("tests/test_research.R")
    results <- list()
    check <- function(section, name, ok, got = "") {
      results[[length(results) + 1]] <<- tibble::tibble(section = section, name = name, ok = isTRUE(ok), got = as.character(got))
    }
  }
  source(here::here("R", "helpers_research.R"))
  s <- "research: parsers"

  check(s, "mechanism: R01 in parenthetical", identical(parse_mechanism("NIMH BRAINS (R01 Clinical Trial Optional)"), "R01"))
  check(s, "mechanism: Collaborative U24", identical(parse_mechanism("Resource (Collaborative U24 - Clinical Trials not allowed)"), "U24"))
  check(s, "mechanism: R43/R44 takes first", identical(parse_mechanism("SBIR Phase I (R43/R44 Clinical Trial Not Allowed)"), "R43"))
  check(s, "mechanism: none gives NA", is.na(parse_mechanism("Small Business Translator: MedTech and Digital Health Technologies")))
  check(s, "mechanism: vectorised", identical(parse_mechanism(c("A (R21)", "B")), c("R21", NA_character_)))

  check(s, "trial: optional", identical(parse_trial_status("Foo (R01 Clinical Trial Optional)"), "optional"))
  check(s, "trial: not allowed (title case)", identical(parse_trial_status("Foo (R01 Clinical Trial Not Allowed)"), "not_allowed"))
  check(s, "trial: not allowed (plural, lower case)", identical(parse_trial_status("Foo (U24 - Clinical Trials not allowed)"), "not_allowed"))
  check(s, "trial: required", identical(parse_trial_status("Foo (R01 Clinical Trial Required)"), "required"))
  check(s, "trial: bare phrase gives NA", is.na(parse_trial_status("Early- and Late-Stage Clinical Trials for the Spectrum of Alzheimer's Disease")))

  check(s, "hs: trial status wins", identical(parse_hs_flag("x", "required"), "trial"))
  check(s, "hs: mentioned in text", identical(parse_hs_flag("involves human subjects", NA_character_), "mentioned"))
  check(s, "hs: neither gives NA", is.na(parse_hs_flag("plain text", NA_character_)))

  check(s, "ic: from RFA number", identical(parse_ic("RFA-AG-26-020", NA_character_), "AG"))
  check(s, "ic: from funding_activity", identical(parse_ic("PAR-22-083", "HL"), "HL"))
  check(s, "ic: none gives NA", is.na(parse_ic("PAR-22-083", NA_character_)))
  check(s, "ic: non-IC code ignored", is.na(parse_ic("PAR-22-083", "ED")))

  s <- "research: payload pool"
  toy <- tibble::tibble(
    opp_id = c("1", "2", "3", "4", "5", "5", "6"),
    opp_number = c("PAR-1", "PAR-2", "PAR-3", "PAR-4", "PAR-5", "PAR-5", "PAR-6"),
    title = c("Keep (R01 Clinical Trial Optional)", "Closed", "Notice", "Not eligible", "Expired", "Expired", "Forecast"),
    agency = "NIH",
    status = c("posted", "closed", "notice", "posted", "posted", "posted", "forecasted"),
    close_date = c("2026-12-01", "2026-12-01", "2026-12-01", "2026-12-01", "2026-11-01", "2026-11-01", NA),
    award_floor = NA_character_, award_ceiling = "500000",
    applicant_types = c("20|25", "20", "20", "00|01", "20", "20", "06"),
    funding_activity = NA_character_,
    summary = c(strrep("x", 3000), "s", "s", "s", "s", "s", "s"),
    url = "https://example.org")
  p <- build_research_payload(toy, as.Date("2026-11-07"))
  check(s, "keeps posted and forecasted eligible rows only", setequal(vapply(p$rows, function(r) r$id, ""), c("1", "6")), p$n)
  check(s, "n matches rows", p$n == length(p$rows))
  check(s, "as_of is ISO text", identical(p$as_of, "2026-11-07"))
  dup <- build_research_payload(rbind(toy[1, ], toy[1, ]), as.Date("2026-11-07"))
  check(s, "duplicate opp_id collapses", dup$n == 1)
  check(s, "summary cut to 1200", nchar(p$rows[[1]]$sum) <= 1200)
  fc <- Filter(function(r) r$id == "6", p$rows)[[1]]
  check(s, "forecast with NA close stays, close is NA", is.na(fc$close))
  js <- jsonlite::toJSON(p$rows, auto_unbox = TRUE, na = "null")
  check(s, "NA close serialises as null", grepl('"close":null', js, fixed = TRUE))
  r1 <- p$rows[[1]]
  check(s, "row has the contract fields", setequal(names(r1), c("id","num","title","agency","status","close","floor","ceil","mech","trial","hs","ic","elig","url","sum")))
  check(s, "row parses mechanism and trial", identical(r1$mech, "R01") && identical(r1$trial, "optional"))
  check(s, "numeric award fields", is.numeric(r1$ceil) && r1$ceil == 500000)

  if (standalone) {
    rep <- dplyr::bind_rows(results)
    if (!all(rep$ok)) print(as.data.frame(rep[!rep$ok, c("section", "name", "got")]))
    cat(sprintf("%d of %d research tests pass\n", sum(rep$ok), nrow(rep)))
    if (!all(rep$ok)) quit(status = 1)
  }
})

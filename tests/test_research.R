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
  check(s, "mechanism: UG3/UH3 takes first", identical(parse_mechanism("Trials (UG3/UH3 - Clinical Trial Required)"), "UG3"))
  check(s, "mechanism: DP2", identical(parse_mechanism("Pioneer Award (DP2)"), "DP2"))
  check(s, "mechanism: RM1 standalone", identical(parse_mechanism("Center RM1 program"), "RM1"))
  check(s, "mechanism: COVID-19 is not a code", is.na(parse_mechanism("COVID-19 vaccine research")))
  check(s, "mechanism: (FY2026) is not a code", is.na(parse_mechanism("Annual report (FY2026)")))
  check(s, "mechanism: (AI2 something) is not a code", is.na(parse_mechanism("Study (AI2 something)")))
  check(s, "mechanism: (B12 deficiency) is not a code", is.na(parse_mechanism("Study (B12 deficiency)")))
  check(s, "mechanism: K99, U24, UM1, SBIR, STTR", identical(parse_mechanism(c("A (K99/R00)", "B (U24)", "C (UM1 - Clinical Trial Optional)", "D (SBIR)", "E (STTR Phase I)")), c("K99", "U24", "UM1", "SBIR", "STTR")))
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
  late <- toy[1, ]; late$status <- "closed"; late2 <- toy[1, ]
  dd <- build_research_payload(rbind(late, late2), as.Date("2026-11-07"))
  check(s, "dedup after filters: later eligible duplicate is kept", dd$n == 1)
  check(s, "summary cut to 1200", nchar(p$rows[[1]]$sum) <= 1200)
  fc <- Filter(function(r) r$id == "6", p$rows)[[1]]
  check(s, "forecast with NA close stays, close is NA", is.na(fc$close))
  js <- jsonlite::toJSON(p$rows, auto_unbox = TRUE, na = "null")
  check(s, "NA close serialises as null", grepl('"close":null', js, fixed = TRUE))
  r1 <- p$rows[[1]]
  check(s, "row has the contract fields", setequal(names(r1), c("id","num","title","agency","status","close","floor","ceil","mech","trial","hs","ic","flags","post","elig","url","sum")))
  check(s, "row parses mechanism and trial", identical(r1$mech, "R01") && identical(r1$trial, "optional"))
  check(s, "numeric award fields", is.numeric(r1$ceil) && r1$ceil == 500000)

  zero <- toy[1, ]; zero$award_ceiling <- "0"; zero$award_floor <- "0"
  pz <- build_research_payload(zero, as.Date("2026-11-07"))
  jz <- jsonlite::toJSON(pz$rows, auto_unbox = TRUE, na = "null")
  check(s, "award ceiling 0 gives ceil null", grepl('"ceil":null', jz, fixed = TRUE), jz)
  check(s, "award floor 0 gives floor null", grepl('"floor":null', jz, fixed = TRUE), jz)
  check(s, "positive ceiling is kept", r1$ceil == 500000)
  check(s, "source_date defaults to as_of", identical(p$source_date, "2026-11-07"))
  ps <- build_research_payload(toy, as.Date("2026-11-09"), as.Date("2026-11-06"))
  check(s, "source_date argument is used and is ISO text", identical(ps$source_date, "2026-11-06") && identical(ps$as_of, "2026-11-09"))
  tf <- toy; tf$fetched_on <- c("2026-11-03", "2026-11-05", rep("2026-11-04", 5))
  check(s, "fetched_on column max wins", identical(build_research_payload(tf, as.Date("2026-11-09"), as.Date("2026-11-06"))$source_date, "2026-11-05"))
  um <- toy[c(1, 7), ]; um$opp_id <- c("u1", "u2"); um$applicant_types <- c("UNMAPPED", "UNMAPPED|00")
  pu <- build_research_payload(um, as.Date("2026-11-07"))
  check(s, "only-UNMAPPED row is in the pool with elig empty", pu$n == 1 && identical(pu$rows[[1]]$id, "u1") && identical(pu$rows[[1]]$elig, ""), pu$n)
  um2 <- toy[1, ]; um2$applicant_types <- "UNMAPPED|20"
  check(s, "UNMAPPED token stripped from elig", identical(build_research_payload(um2, as.Date("2026-11-07"))$rows[[1]]$elig, "20"))

  s <- "research: flags"
  fl <- function(sum = "", elig = "", cs = NA_character_) parse_flags(sum, elig, cs)[[1]]
  check(s, "flag: letter of intent", identical(fl("Letter of intent due 2026-12-01")$loi, "yes"))
  check(s, "flag: cost sharing Yes / No / NA", identical(fl(cs = "Yes")$cost_share, "yes") && identical(fl(cs = "No")$cost_share, "no") && is.null(fl(cs = NA_character_)$cost_share))
  check(s, "flag: foreign component, not foreign-born", identical(fl("Applicants must include a foreign component")$foreign, "yes") && is.null(fl("foreign-born residents")$foreign))
  check(s, "flag: IND/IDE whole upper-case word only", identical(fl("Investigational New Drug (IND) application")$ind_ide, "yes") && identical(fl("needs an IDE")$ind_ide, "yes") && is.null(fl("individual investigators behind the study")$ind_ide))
  check(s, "flag: data sharing", identical(fl("data sharing plan")$data_sharing, "yes") && identical(fl("Data Management and Sharing")$data_sharing, "yes"))
  check(s, "flag: animals and human subjects", identical(fl("animal models")$animals, "yes") && identical(fl("human subjects")$human_subjects, "yes"))
  check(s, "flag: multi-PI", identical(fl("multiple principal investigators")$multi_pi, "yes") && identical(fl("multi-PI")$multi_pi, "yes"))
  check(s, "flag: subaward", identical(fl("subaward")$subaward, "yes") && identical(fl("subaward/subcontract")$subaward, "yes"))
  check(s, "flag: empty and NA give an empty list", identical(parse_flags(c("", NA), c(NA, ""), c(NA, NA)), list(list(), list())))
  check(s, "flag: eligibility text is searched too", identical(fl("", "Foreign components, as defined in the NIH Grants Policy Statement, are allowed")$foreign, "yes"))
  check(s, "flag: boilerplate 'not eligible' does not set foreign", is.null(fl("Non-domestic Entities (Foreign Organizations) are not eligible to apply")$foreign))
  fx <- toy[c(1, 7), ]
  fx$post_date <- c("2026-10-01", NA); fx$cost_sharing <- c("Yes", NA); fx$eligibility_text <- c("", "")
  fx$summary <- c("Letter of intent required.", "s")
  pf <- build_research_payload(fx, as.Date("2026-11-07"))
  check(s, "payload rows carry flags and post", identical(pf$rows[[1]]$flags$loi, "yes") && identical(pf$rows[[1]]$flags$cost_share, "yes") && identical(pf$rows[[1]]$post, "2026-10-01") &&
    length(pf$rows[[2]]$flags) == 0 && is.na(pf$rows[[2]]$post))
  check(s, "payload tolerates missing flag columns", is.list(p$rows[[1]]$flags) && is.na(p$rows[[1]]$post))

  if (standalone) {
    rep <- dplyr::bind_rows(results)
    if (!all(rep$ok)) print(as.data.frame(rep[!rep$ok, c("section", "name", "got")]))
    cat(sprintf("%d of %d research tests pass\n", sum(rep$ok), nrow(rep)))
    if (!all(rep$ok)) quit(status = 1)
  }
})

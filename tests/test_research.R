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
  source(here::here("R", "00_config.R"))
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
    forecasted_close_date = c("2027-01-01", NA, NA, NA, NA, NA, "2027-02-01"),
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
  check(s, "row has the contract fields", setequal(names(r1), c("id","num","title","agency","status","close","floor","ceil","mech","trial","hs","ic","flags","post","est","elig","url","sum")))
  check(s, "forecasted row carries the estimated close date as est", identical(fc$est, "2027-02-01"))
  check(s, "estimate does not become the close date", is.na(fc$close))
  check(s, "posted row ignores a forecasted_close_date (est is NA)", is.na(r1$est))
  past <- toy[7, ]; past$forecasted_close_date <- "2026-01-01"
  pp <- build_research_payload(past, as.Date("2026-11-07"))
  check(s, "forecast with a past estimate is still kept (estimate never filters)", pp$n == 1 && identical(pp$rows[[1]]$est, "2026-01-01"))
  nocol <- build_research_payload(toy[7, setdiff(names(toy), "forecasted_close_date")], as.Date("2026-11-07"))
  check(s, "no forecasted_close_date column gives est NA", is.na(nocol$rows[[1]]$est))
  check(s, "est serialises as null when missing", grepl('"est":null', js, fixed = TRUE))
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
  check(s, "flag: 'may not include foreign components' does not set foreign", is.null(fl("Applicants may not include foreign components")$foreign))
  check(s, "flag: run-on 'not eligible ... are eligible' does not set foreign", is.null(fl("foreign entities are not eligible to compete for or receive funds and are eligible only as subrecipients")$foreign))
  check(s, "flag: 'must include a foreign component' still sets foreign", identical(fl("Applicants must include a foreign component")$foreign, "yes"))
  fx <- toy[c(1, 7), ]
  fx$post_date <- c("2026-10-01", NA); fx$cost_sharing <- c("Yes", NA); fx$eligibility_text <- c("", "")
  fx$summary <- c("Letter of intent required.", "s")
  pf <- build_research_payload(fx, as.Date("2026-11-07"))
  check(s, "payload rows carry flags and post", identical(pf$rows[[1]]$flags$loi, "yes") && identical(pf$rows[[1]]$flags$cost_share, "yes") && identical(pf$rows[[1]]$post, "2026-10-01") &&
    length(pf$rows[[2]]$flags) == 0 && is.na(pf$rows[[2]]$post))
  check(s, "payload tolerates missing flag columns", is.list(p$rows[[1]]$flags) && is.na(p$rows[[1]]$post))

  ent <- toy[1, ]
  ent$title <- "Imaging &#8211; AI (R01 Clinical Trial Optional) &amp; O&#8217;Brien&#x2019;s&#160;lab&#8203;"
  ent$summary <- "Don&#8217;t use &#8220;raw&#8221; text &#8212; ok &lt;b&gt;"
  pe <- build_research_payload(ent, as.Date("2026-11-07"))
  check(s, "title entities decoded", identical(pe$rows[[1]]$title, "Imaging – AI (R01 Clinical Trial Optional) & O’Brien’s lab"), pe$rows[[1]]$title)
  check(s, "summary entities decoded", identical(pe$rows[[1]]$sum, "Don’t use “raw” text — ok <b>"), pe$rows[[1]]$sum)
  check(s, "mechanism still parsed after decoding", identical(pe$rows[[1]]$mech, "R01"))
  check(s, "text without entities is untouched", identical(p$rows[[1]]$title, "Keep (R01 Clinical Trial Optional)"))
  check(s, "more named entities decoded", identical(decode_entities("A&ndash;B &mdash; it&rsquo;s &lsquo;x&rsquo; &ldquo;y&rdquo; &sect;3 Foo&trade; &hellip; &eacute;"), "A–B — it’s ‘x’ “y” §3 Foo™ … é"))
  check(s, "unknown named entity left alone", identical(decode_entities("a &zzzz; b"), "a &zzzz; b"))

  s <- "merge_grantsgov_fields"
  one <- data.frame(opp_id = "1", opp_number = "RFA-AG-26-020", title = "T (R01)", agency = "NIH", status = "posted", close_date = "2026-12-31",
                    award_floor = NA, award_ceiling = NA, applicant_types = "20", summary = "x", url = "u", stringsAsFactors = FALSE)
  simp <- data.frame(opp_id = c("1", "2"), url = c("https://simpler.grants.gov/opportunity/a", "https://simpler.grants.gov/opportunity/b"), stringsAsFactors = FALSE)
  gg <- data.frame(opp_id = c("1", "9"), url = c("https://www.grants.gov/search-results-detail/1", "https://www.grants.gov/search-results-detail/9"),
                   post_date = c("2026-01-05", "2026-01-06"), cost_sharing = c("Yes", "No"),
                   eligibility_text = c("Foreign organizations are allowed.", "x"), stringsAsFactors = FALSE)
  m <- merge_grantsgov_fields(simp, gg)
  check(s, "matched row takes Grants.gov url, post date, cost sharing and eligibility text",
        identical(m$url[1], "https://www.grants.gov/search-results-detail/1") && m$post_date[1] == "2026-01-05" && m$cost_sharing[1] == "Yes" && grepl("Foreign", m$eligibility_text[1]))
  check(s, "unmatched row keeps its Simpler url, other fields stay NA", identical(m$url[2], "https://simpler.grants.gov/opportunity/b") && is.na(m$post_date[2]) && is.na(m$cost_sharing[2]))
  check(s, "row count and order unchanged, Grants.gov-only rows not added", identical(m$opp_id, c("1", "2")))
  check(s, "NULL Grants.gov table leaves rows alone", identical(merge_grantsgov_fields(simp, NULL)$url, simp$url))
  mg <- build_research_payload(merge_grantsgov_fields(one, gg), as.Date("2026-11-07"))
  check(s, "merged fields reach the payload: flags, post date, url", identical(mg$rows[[1]]$flags$cost_share, "yes") && identical(mg$rows[[1]]$post, "2026-01-05") && grepl("www.grants.gov", mg$rows[[1]]$url))

  s <- "fit_research_payload"
  mk <- function(n, len) list(as_of = "2026-11-10", source_date = "2026-11-10", n = n, rows = lapply(seq_len(n), function(i) list(id = as.character(i), title = "T", sum = strrep("abcdefghi ", len %/% 10))))
  bytes_of <- function(p) nchar(as.character(jsonlite::toJSON(p, auto_unbox = TRUE, na = "null")), type = "bytes")
  big <- mk(200, 1200)
  roomy <- fit_research_payload(big, bytes_of(big) + 1000L)
  check(s, "under budget: payload is returned unchanged", identical(roomy, big))
  tight <- fit_research_payload(big, as.integer(bytes_of(big) * 0.8))
  check(s, "over budget: summaries are shortened until it fits", bytes_of(tight) <= as.integer(bytes_of(big) * 0.8) && max(vapply(tight$rows, function(r) nchar(r$sum), 0L)) < 1200L)
  check(s, "over budget: no row is dropped and nothing but sum changes", tight$n == 200L && identical(vapply(tight$rows, function(r) r$title, ""), rep("T", 200)))
  check(s, "over budget: summaries are never cut below the floor", min(vapply(tight$rows, function(r) nchar(r$sum), 0L)) >= RESEARCH_SUM_FLOOR)
  check(s, "budget the floor cannot meet stops with an error", inherits(try(fit_research_payload(big, 1000L), silent = TRUE), "try-error"))
  check(s, "headroom: the build budget sits at least 5 percent under the hard limit", RESEARCH_PAYLOAD_BUDGET <= 0.95 * RESEARCH_PAYLOAD_LIMIT)

  s <- "research size headroom"
  check(s, "headroom is budget minus bytes", research_headroom(1833689, 1850000) == 16311)
  check(s, "headroom below the minimum is flagged", !research_headroom_ok(1840001, 1850000, 10000) && research_headroom_ok(1840000, 1850000, 10000))
  check(s, "a payload over the budget has negative headroom and fails", research_headroom(1851000, 1850000) < 0 && !research_headroom_ok(1851000, 1850000, 10000))
  check(s, "minimum headroom is 10 KB and sits inside the budget", RESEARCH_MIN_HEADROOM == 10000L && RESEARCH_MIN_HEADROOM < RESEARCH_PAYLOAD_BUDGET)
  rj_bytes <- file.size(here::here("data", "processed", "research.json"))
  check(s, paste0("committed research.json leaves at least ", RESEARCH_MIN_HEADROOM, " bytes under the budget (now ", rj_bytes, ", headroom ", research_headroom(rj_bytes, RESEARCH_PAYLOAD_BUDGET), ")"),
        research_headroom_ok(rj_bytes, RESEARCH_PAYLOAD_BUDGET, RESEARCH_MIN_HEADROOM))

  s <- "grantsgov_lookup"
  syn <- list(data = list(id = 364247L, synopsis = list(postingDateStr = "2026-11-10-00-00-00", costSharing = FALSE)))
  fc <- list(data = list(id = 364251L, synopsis = list(), forecast = list(postingDateStr = "2026-11-09-00-00-00", costSharing = TRUE)))
  d1 <- parse_grantsgov_detail(syn)
  check(s, "synopsis record: post date as YYYY-MM-DD, cost sharing No", identical(d1$post_date, "2026-11-10") && identical(d1$cost_sharing, "No"))
  d2 <- parse_grantsgov_detail(fc)
  check(s, "forecast record is read from the forecast block, cost sharing Yes", identical(d2$post_date, "2026-11-09") && identical(d2$cost_sharing, "Yes"))
  d3 <- parse_grantsgov_detail(list(data = list(id = 1L)))
  check(s, "record with neither block gives NA, not an error", is.na(d3$post_date) && is.na(d3$cost_sharing))
  check(s, "NULL response gives NA", is.na(parse_grantsgov_detail(NULL)$post_date))
  check(s, "grants.gov link has the same shape as opportunities.csv", identical(grantsgov_url("364247"), "https://www.grants.gov/search-results-detail/364247"))
  pool <- data.frame(opp_id = c("1", "2", "3", "2"), stringsAsFactors = FALSE)
  check(s, "unmatched ids: in the pool, not in the Grants.gov table, once each", identical(unmatched_opp_ids(pool, data.frame(opp_id = "1")), c("2", "3")))
  check(s, "unmatched ids: no Grants.gov table means every id", identical(unmatched_opp_ids(pool, NULL), c("1", "2", "3")))
  base_gg <- data.frame(opp_id = "1", url = "https://www.grants.gov/search-results-detail/1", post_date = "2020-01-01", cost_sharing = "No", eligibility_text = "e", stringsAsFactors = FALSE)
  lk <- data.frame(opp_id = c("1", "2"), url = c("u1", "u2"), post_date = c("2026-01-01", "2026-11-10"), cost_sharing = c("Yes", "No"), stringsAsFactors = FALSE)
  both <- add_grantsgov_lookup(base_gg, lk)
  check(s, "lookup adds only ids the Grants.gov table lacks; existing row wins", identical(both$opp_id, c("1", "2")) && both$post_date[1] == "2020-01-01" && both$url[2] == "u2" && is.na(both$eligibility_text[2]))
  check(s, "no lookup leaves the Grants.gov table alone", identical(add_grantsgov_lookup(base_gg, NULL), base_gg))
  mm <- merge_grantsgov_fields(data.frame(opp_id = "2", url = "https://simpler.grants.gov/opportunity/x", stringsAsFactors = FALSE), both)
  check(s, "looked-up row reaches merge_grantsgov_fields with its grants.gov link and post date", identical(mm$url, "u2") && mm$post_date == "2026-11-10" && mm$cost_sharing == "No")

  s <- "ic from summary"
  check(s, "parenthesised acronym after Institute", identical(parse_ic("PAR-25-001", NA_character_, "Through this NOFO, the National Cancer Institute (NCI) solicits grant applications proposing to develop tools."), "CA"))
  check(s, "acronym alone in the first sentence", identical(parse_ic("PAR-25-343", NA_character_, "The NIDCD is committed to identifying effective interventions. More text follows."), "DC"))
  check(s, "opportunity number wins over the summary", identical(parse_ic("RFA-AG-26-020", NA_character_, "The National Cancer Institute (NCI) solicits applications."), "AG"))
  check(s, "funding_activity wins over the summary", identical(parse_ic("PAR-22-083", "HL", "The National Cancer Institute (NCI) solicits applications."), "HL"))
  check(s, "first sentence naming two institutes is not guessed", is.na(parse_ic("PAR-25-002", NA_character_, "The NEI and the NCI jointly invite applications for imaging. Details follow.")))
  check(s, "an institute named only after the first sentence is ignored", is.na(parse_ic("PAR-25-003", NA_character_, "This NOFO supports research on vision. NEI is the lead.")))
  check(s, "NIAID is not read as NIA", identical(parse_ic("PAR-25-004", NA_character_, "NIAID supports this program."), "AI"))
  check(s, "lower-case acronyms are not matched", is.na(parse_ic("PAR-25-005", NA_character_, "a study of nia and nci markers.")))
  check(s, "non-NIH funder names are not matched", is.na(parse_ic("22-600", NA_character_, "The National Science Foundation (NSF) supports research.")))
  check(s, "NA or empty summary gives NA", all(is.na(parse_ic(c("PAR-1", "PAR-2"), NA_character_, c(NA_character_, "")))))
  check(s, "vectorised over rows", identical(parse_ic(c("RFA-AG-26-020", "PAR-1", "PAR-2"), NA_character_, c(NA_character_, "NIMH seeks applications.", "Plain text.")), c("AG", "MH", NA_character_)))
  check(s, "two-argument calls still work", identical(parse_ic("PAR-22-083", "HL"), "HL"))
  ic_toy <- toy[1, ]
  ic_toy$opp_number <- "PAR-25-343"; ic_toy$agency <- "National Institutes of Health"; ic_toy$summary <- "The NIDCD is committed to identifying effective interventions."
  check(s, "payload: NIH row gets its institute from the summary", identical(build_research_payload(ic_toy, as.Date("2026-11-07"))$rows[[1]]$ic, "DC"))
  ic_toy$agency <- "U.S. National Science Foundation"
  check(s, "payload: non-NIH row with the same text stays unknown", is.na(build_research_payload(ic_toy, as.Date("2026-11-07"))$rows[[1]]$ic))

  s <- "grantsgov_lookup: eligibility text"
  syn_e <- list(data = list(id = 1L, synopsis = list(postingDateStr = "2026-11-10-00-00-00", costSharing = FALSE, applicantEligibilityDesc = "Foreign organizations are allowed to apply. See &quot;Description&quot; &amp; subawards.")))
  fc_e <- list(data = list(id = 2L, synopsis = list(), forecast = list(postingDateStr = "2026-11-09-00-00-00", costSharing = TRUE, applicantEligibilityDesc = "Open to universities only.")))
  check(s, "synopsis record: eligibility text read and entities decoded", identical(parse_grantsgov_detail(syn_e)$eligibility_text, "Foreign organizations are allowed to apply. See \"Description\" & subawards."))
  check(s, "forecast record: eligibility text read from the forecast block", identical(parse_grantsgov_detail(fc_e)$eligibility_text, "Open to universities only."))
  check(s, "empty or missing eligibility text gives NA", is.na(parse_grantsgov_detail(list(data = list(synopsis = list(postingDateStr = "2026-11-10-00-00-00", costSharing = FALSE, applicantEligibilityDesc = ""))))$eligibility_text) && is.na(parse_grantsgov_detail(syn)$eligibility_text) && is.na(parse_grantsgov_detail(NULL)$eligibility_text))
  check(s, "eligibility text does not disturb post date and cost sharing", identical(parse_grantsgov_detail(syn_e)$post_date, "2026-11-10") && identical(parse_grantsgov_detail(syn_e)$cost_sharing, "No"))
  lk_e <- data.frame(opp_id = "2", url = "u2", post_date = "2026-11-09", cost_sharing = "Yes", eligibility_text = "Foreign organizations are allowed to apply.", stringsAsFactors = FALSE)
  both_e <- add_grantsgov_lookup(base_gg, lk_e)
  check(s, "lookup eligibility text is carried into the Grants.gov table", identical(both_e$eligibility_text, c("e", "Foreign organizations are allowed to apply.")))
  one_e <- one
  one_e$opp_id <- "2"
  pe <- build_research_payload(merge_grantsgov_fields(one_e, both_e), as.Date("2026-11-07"))
  check(s, "looked-up eligibility text fills the foreign flag in the payload", identical(pe$rows[[1]]$flags$foreign, "yes"))

  if (standalone) {
    rep <- dplyr::bind_rows(results)
    if (!all(rep$ok)) print(as.data.frame(rep[!rep$ok, c("section", "name", "got")]))
    cat(sprintf("%d of %d research tests pass\n", sum(rep$ok), nrow(rep)))
    if (!all(rep$ok)) quit(status = 1)
  }
})

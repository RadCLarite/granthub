# test_foundations.R: validator and payload for the foundation list (R/helpers_research.R, R/15_build_foundations.R).
# Sourced by run_tests.R, which provides check(); also runnable alone: Rscript tests/test_foundations.R

local({
  standalone <- !exists("check", mode = "function")
  if (standalone) {
    here::i_am("tests/test_foundations.R")
    results <- list()
    check <- function(section, name, ok, got = "") {
      results[[length(results) + 1]] <<- tibble::tibble(section = section, name = name, ok = isTRUE(ok), got = as.character(got))
    }
  }
  source(here::here("R", "helpers_research.R"))
  s <- "foundations"
  asof <- as.Date("2026-11-10")
  good <- tibble::tibble(id = c("a", "b"), name = c("Fund A", "Fund B"), focus = c("Funds stroke imaging research.", "Funds cancer screening."),
    career_stage = c("early", ""), award_note = c("", "Up to the stated amount on the page"),
    url = c("https://example.org/a", "https://example.org/b"), verified_on = c("2026-11-01", "2026-10-15"))
  check(s, "valid rows give no errors", length(validate_foundations(good, asof)) == 0)
  bad <- function(col, val, i = 1) { d <- good; d[[col]][i] <- val; validate_foundations(d, asof) }
  check(s, "missing url is an error", length(bad("url", "")) >= 1)
  check(s, "http url is an error", length(bad("url", "http://example.org/a")) >= 1)
  check(s, "unparseable verified_on is an error", length(bad("verified_on", "last week")) >= 1)
  check(s, "unpadded verified_on is an error", length(bad("verified_on", "2026-1-5")) >= 1)
  check(s, "verified_on with trailing text is an error", length(bad("verified_on", "2026-11-01 (checked)")) >= 1)
  check(s, "future verified_on is an error", length(bad("verified_on", "2027-01-01")) >= 1)
  check(s, "missing focus is an error", length(bad("focus", "")) >= 1)
  check(s, "missing name is an error", length(bad("name", "")) >= 1)
  check(s, "duplicate id is an error", length(bad("id", "a", 2)) >= 1)
  check(s, "empty career_stage and award_note are fine", length(validate_foundations(good, asof)) == 0)
  check(s, "zero-row table is valid", length(validate_foundations(good[0, ], asof)) == 0)
  p <- build_foundations_payload(good, asof)
  check(s, "payload shape", p$n == 2 && identical(p$as_of, "2026-11-10") && setequal(names(p$rows[[1]]), c("id", "name", "focus", "career", "note", "url", "verified")))
  check(s, "payload keeps empty note as null-able NA", is.na(p$rows[[1]]$note) && identical(p$rows[[2]]$note, "Up to the stated amount on the page"))
  p0 <- build_foundations_payload(good[0, ], asof)
  check(s, "empty payload has n 0 and empty rows", p0$n == 0L && length(p0$rows) == 0)

  tmp <- tempfile(fileext = ".csv")
  d <- good; d$url[1] <- "http://example.org/a"
  readr::write_csv(d, tmp)
  rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  run_builder <- function(csv, json) {
    Sys.setenv(FOUNDATIONS_CSV = csv, FOUNDATIONS_OUT = json); on.exit(Sys.unsetenv(c("FOUNDATIONS_CSV", "FOUNDATIONS_OUT")))
    suppressWarnings(system2(rs, shQuote(here::here("R", "15_build_foundations.R")), stdout = TRUE, stderr = TRUE))
  }
  out <- run_builder(tmp, tempfile(fileext = ".json"))
  check(s, "builder stops on a bad CSV and names the problem", !is.null(attr(out, "status")) && any(grepl("https", out)), paste(utils::tail(out, 2), collapse = " | "))
  tmp2 <- tempfile(fileext = ".csv"); tmpj <- tempfile(fileext = ".json"); readr::write_csv(good, tmp2)
  out2 <- run_builder(tmp2, tmpj)
  check(s, "builder writes the JSON for a good CSV", is.null(attr(out2, "status")) && file.exists(tmpj) && jsonlite::read_json(tmpj)$n == 2, paste(utils::tail(out2, 2), collapse = " | "))

  if (standalone) {
    rep <- dplyr::bind_rows(results)
    if (!all(rep$ok)) print(as.data.frame(rep[!rep$ok, c("section", "name", "got")]))
    cat(sprintf("%d of %d foundation tests pass\n", sum(rep$ok), nrow(rep)))
    if (!all(rep$ok)) quit(status = 1)
  }
})

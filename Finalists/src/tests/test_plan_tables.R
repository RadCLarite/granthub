# test_plan_tables.R: checks on the combined agency plan tables (plan_text_check.csv, agency_goal_summaries.csv).
# Sourced by run_tests.R, which provides check(). Every goal quote must sit on its cited page of the extracted plan text.

local({
  s <- "plans: combined tables"
  docs <- here::here("src", "docs")
  man  <- readr::read_csv(file.path(DIR_RAW, "agency_plans", "MANIFEST.csv"), show_col_types = FALSE)
  chk  <- readr::read_csv(file.path(docs, "plan_text_check.csv"), show_col_types = FALSE)
  gl   <- readr::read_csv(file.path(docs, "agency_goal_summaries.csv"), show_col_types = FALSE, col_types = readr::cols(.default = "c"))

  check(s, "plan_text_check has one row per manifest entry", nrow(chk) == nrow(man) && setequal(chk$file, man$file), nrow(chk))
  check(s, "every plan has at least one goal row", all(as.character(seq_len(nrow(man))) %in% gl$row))
  check(s, "no goal row has an empty quote", !anyNA(gl$goal_text_exact) && all(nzchar(gl$goal_text_exact)))
  check(s, "goal_kind is one of the allowed values", all(gl$goal_kind %in% c("goal", "division_goal", "priority", "division_name", "goal_unlabeled")))
  check(s, "every goal row carries the agency's own label as its category", !anyNA(gl$classification_category) && all(nzchar(gl$classification_category)))

  squish <- function(x) gsub("\\s+", " ", trimws(x))
  pages_of <- function(stem) {
    t <- paste(readLines(file.path(DIR_PROCESSED, "agency_plan_text", "all", paste0(stem, ".txt")), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    p <- strsplit(t, "===== PAGE ", fixed = TRUE)[[1]][-1]
    setNames(squish(sub("^[0-9]+( \\[OCR\\])? =====", "", p)), sub("^([0-9]+).*", "\\1", p))
  }
  cache <- list()
  ok <- vapply(seq_len(nrow(gl)), function(i) {
    stem <- sub("\\.pdf$", "", gl$plan_file[i])
    if (is.null(cache[[stem]])) cache[[stem]] <<- pages_of(stem)
    pg <- cache[[stem]][gl$plan_page[i]]
    !is.na(pg) && grepl(squish(gl$goal_text_exact[i]), pg, fixed = TRUE)
  }, logical(1))
  check(s, "every goal quote is found on its cited plan page", all(ok), paste(sum(!ok), "misses"))
  has <- !is.na(gl$goal_statement) & nzchar(gl$goal_statement)
  ok2 <- vapply(which(has), function(i) {
    stem <- sub("\\.pdf$", "", gl$plan_file[i])
    pg <- cache[[stem]][gl$plan_page[i]]
    !is.na(pg) && grepl(squish(gl$goal_statement[i]), pg, fixed = TRUE)
  }, logical(1))
  check(s, "every goal_statement is found on its cited plan page", all(ok2), paste(sum(has), "statements,", sum(!ok2), "misses"))
})

# check_facts.R: every number used on a slide is a row in data/manual/facts.csv with an R
# expression that reproduces it from the pipeline outputs. Presentation numbers must pass here.
# Columns: fact_id, fact, expr, expected, tol. Expressions can use `items`, `ranking`,
# `dropped`, `all_items`, `criteria`, `payload` (payload.json) and `backtest` (rankings_backtest.csv) and `bt_result` (backtest_result.csv, Everett) and `bt_v2` (backtest_v2_result.csv) and `bt_tune` (backtest_tune_result.csv). Prints "N of N rows pass".
# Run from Finalists/src: Rscript R/check_facts.R

here::i_am("src/R/check_facts.R")
# The facts describe the frozen snapshot: pin the scoring clock (AS_OF_DATE, 00_config.R) to the snapshot date, not today.
Sys.setenv(AS_OF_DATE = "2026-11-07")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_io.R"))
source(here::here("src", "R", "score.R"))
suppressPackageStartupMessages(library(readr))
stopifnot(identical(AS_OF_DATE, SNAPSHOT_AS_OF_DATE))
# items.csv and payload.json are rebuilt by the daily job for today's date. The facts hold only for the snapshot build.
.p_as_of <- if (file.exists(PAYLOAD_JSON)) substr(jsonlite::fromJSON(PAYLOAD_JSON, simplifyVector = FALSE)$data_as_of, 1, 10) else NA_character_
if (!identical(.p_as_of, format(SNAPSHOT_AS_OF_DATE)))
  stop("payload.json is stamped ", .p_as_of, ", not the snapshot date ", format(SNAPSHOT_AS_OF_DATE),
       ". Rebuild first: AS_OF_DATE=", format(SNAPSHOT_AS_OF_DATE), " Rscript R/10_run_ranking.R; AS_OF_DATE=", format(SNAPSHOT_AS_OF_DATE), " Rscript R/11_build_payload.R", call. = FALSE)

items <- read_any(ITEMS_FILE)
criteria <- read_csv(CRITERIA_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
criteria$weight <- if ("weight" %in% names(criteria)) suppressWarnings(as.numeric(criteria$weight)) else NA_real_
rk <- rank_items(items, criteria, REF_DATE, ID_COL, NAME_COL)
ranking <- rk$ranked; dropped <- rk$dropped; all_items <- rk$all

payload <- if (file.exists(PAYLOAD_JSON)) jsonlite::fromJSON(PAYLOAD_JSON) else NULL
backtest <- if (file.exists(BACKTEST_CSV)) read_csv(BACKTEST_CSV, show_col_types = FALSE) else NULL
bt_result <- if (file.exists(file.path(DIR_PROCESSED, "backtest_result.csv"))) read_csv(file.path(DIR_PROCESSED, "backtest_result.csv"), show_col_types = FALSE) else NULL
bt_v2 <- if (file.exists(file.path(DIR_PROCESSED, "backtest_v2_result.csv"))) read_csv(file.path(DIR_PROCESSED, "backtest_v2_result.csv"), show_col_types = FALSE) else NULL

bt_tune <- if (file.exists(file.path(DIR_PROCESSED, "backtest_tune_result.csv"))) read_csv(file.path(DIR_PROCESSED, "backtest_tune_result.csv"), show_col_types = FALSE) else NULL

facts <- read_csv(FACTS_FILE, show_col_types = FALSE, col_types = cols(.default = col_character()))
facts$got <- NA_character_; facts$pass <- FALSE
for (i in seq_len(nrow(facts))) {
  got <- tryCatch(eval(parse(text = facts$expr[i])), error = function(e) paste("ERROR:", conditionMessage(e)))
  facts$got[i] <- paste(got, collapse = ",")
  exp_num <- suppressWarnings(as.numeric(facts$expected[i]))
  tol <- suppressWarnings(as.numeric(facts$tol[i])); if (is.na(tol)) tol <- 0
  facts$pass[i] <- if (!is.na(exp_num) && is.numeric(got)) abs(got[1] - exp_num) <= tol else identical(facts$got[i], facts$expected[i])
}
if (!all(facts$pass)) print(as.data.frame(facts[!facts$pass, c("fact_id", "fact", "expected", "got")]))
cat(sprintf("%d of %d rows pass%s\n", sum(facts$pass), nrow(facts), if (USING_EXAMPLE) " (on TOY example data)" else ""))
if (!all(facts$pass)) quit(status = 1)

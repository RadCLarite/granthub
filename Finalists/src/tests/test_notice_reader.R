# test_notice_reader.R: notice reader tests with a mock model. No network, no key.
# Run from Finalists/src: Rscript tests/test_notice_reader.R
here::i_am("src/tests/test_notice_reader.R")
source(here::here("src", "R", "30_notice_reader.R"))
DIR_CACHE_NOTICE <- file.path(tempdir(), "notice_cache")   # never touch the real cache
txt <- "Eligible applicants: State governments and Indian Tribes may apply. Counties are not eligible."
ok <- 0; total <- 0
t <- function(name, cond) { total <<- total + 1; ok <<- ok + isTRUE(cond); cat(if (isTRUE(cond)) "PASS" else "FAIL", name, "\n") }
good  <- function(p) '{"label":"lead","evidence":"State governments and Indian Tribes may apply"}'
fake  <- function(p) '{"label":"lead","evidence":"All agencies are eligible"}'
boom  <- function(p) stop("network call attempted")
calls <- new.env(); calls$n <- 0L

t("live off + no cache: no call, skipped", { r <- read_notice(txt, live = FALSE, calls, boom); r$skipped && is.na(r$reader_label) })
t("live on: real quote accepted", { r <- read_notice(txt, TRUE, calls, good); r$reader_label == "lead" && r$quote_ok })
t("second read comes from cache, no call", { r <- read_notice(txt, FALSE, calls, boom); r$cached && r$reader_label == "lead" })
t("one live call counted", calls$n == 1L)
txt2 <- paste(txt, "Extra sentence.")
t("quote not in text is thrown out", { r <- read_notice(txt2, TRUE, calls, fake); r$reader_label == "unclear" && !r$quote_ok && is.na(r$reader_quote) })
NOTICE_MAX_CALLS <- 2L
t("cap stops further live calls", { r <- read_notice(paste(txt, "Another."), TRUE, calls, good); r$skipped })
t("bad JSON falls back to unclear", { r <- read_notice("x y z", TRUE, new.env(), function(p) "not json"); r$reader_label == "unclear" })
cat(sprintf("%d of %d tests pass\n", ok, total)); if (ok < total) quit(status = 1)

# 31_swipe_summary.R: plain-language summary shown on the tool's swipe card.
# An LLM reads the notice text (title, summary, eligibility) and writes 2 short sentences for a non-expert
# state grant writer: what the money pays for, who can apply, and any hard requirement. It also returns one
# exact quote from the text that supports the summary. A summary whose quote is not found in the text is
# thrown out (the tool falls back to the first-sentence snippet). It never sets rank, eligibility or tier.
#
# Safe by default: with no flags it reads the cache only and makes NO model call.
#   Live calls need:  SWIPE_SUMMARY_LIVE=yes  plus  AOAI_ENDPOINT and AOAI_KEY (env vars, never in files).
#   Calls per run are capped by SWIPE_MAX_CALLS. Every response is cached before use.
# Output: data/processed/swipe_summary.csv (opp_id, ai_summary, ai_quote, quote_ok, cached).
# Run from Finalists/src:  Rscript R/31_swipe_summary.R

suppressPackageStartupMessages({ library(here); library(dplyr); library(stringr); library(readr); library(jsonlite) })
here::i_am("src/R/31_swipe_summary.R")
source(here::here("src", "R", "00_config.R"))
source(here::here("src", "R", "helpers_llm.R"))   # normalize_text()

SWIPE_MAX_CALLS   <- 700L                      # hard cap on live calls per run (558 unique opportunities in the payload)
SWIPE_DEPLOYMENT  <- "gpt-4o-mini"
SWIPE_PROMPT_VER  <- "s2"                      # bump to invalidate cached summaries
SWIPE_API_VERSION <- "2024-06-01"
SWIPE_MAX_TEXT    <- 6000L                     # characters sent per item
DIR_CACHE_SWIPE   <- here::here("data", "cache", "llm_swipe")

# Notice text carries HTML entities (&#8217; &amp;); decode them so quotes match and summaries read cleanly.
unent <- function(x) {
  x <- str_replace_all(x, "&#8217;|&#x2019;|&rsquo;", "'")
  x <- str_replace_all(x, "&amp;", "&") |> str_replace_all("&nbsp;", " ") |> str_replace_all("&quot;|&ldquo;|&rdquo;", "\"")
  x <- str_replace_all(x, "&#8211;|&#8212;|&ndash;|&mdash;", "-")
  str_replace_all(x, "&#\\d+;", "")
}

swipe_prompt <- function(title, text) paste0(
  "You help a North Carolina state agency grant writer decide quickly whether a federal funding notice is worth a closer look.\n",
  "Write ai_summary: exactly two plain sentences, 45 words or fewer in total. Sentence 1: what the money pays for. ",
  "Sentence 2: who can apply, naming the applicant types the text lists, and the one requirement or limit that matters most (match, narrow topic, region) only if the text states one. ",
  "Never write that something is 'not mentioned' or 'not specified'; leave it out. Say what the program does, not that it is 'scientific excellence' or similar slogans. ",
  "Use only facts in the text. No marketing words, no advice, no dollar amounts, no dates.\n",
  "Write ai_quote: one exact phrase of 4 to 20 words copied word for word from the text that supports sentence 1, without surrounding quotation marks.\n",
  "Reply with JSON only: {\"ai_summary\": \"...\", \"ai_quote\": \"...\"}\n\n",
  "TITLE: ", title, "\nTEXT: ", text)

aoai_chat <- function(prompt) {
  ep <- Sys.getenv("AOAI_ENDPOINT"); key <- Sys.getenv("AOAI_KEY")
  if (!nzchar(ep) || !nzchar(key)) stop("Set AOAI_ENDPOINT and AOAI_KEY in the environment (not in a file).")
  url <- sprintf("%s/openai/deployments/%s/chat/completions?api-version=%s",
                 sub("/$", "", ep), SWIPE_DEPLOYMENT, SWIPE_API_VERSION)
  resp <- httr2::request(url) |> httr2::req_headers(`api-key` = key) |> httr2::req_timeout(60) |>
    httr2::req_retry(max_tries = 5) |>
    httr2::req_body_json(list(temperature = 0, seed = LLM_SEED, max_tokens = 160,
      response_format = list(type = "json_object"),
      messages = list(list(role = "user", content = prompt)))) |>
    httr2::req_perform() |> httr2::resp_body_json()
  resp$choices[[1]]$message$content
}

summarize_one <- function(title, text, live = FALSE, calls = new.env(), chat_fn = aoai_chat) {
  text <- substr(normalize_text(unent(text)), 1, SWIPE_MAX_TEXT)
  prompt <- swipe_prompt(normalize_text(title), text)
  key <- digest::digest(list(SWIPE_DEPLOYMENT, SWIPE_PROMPT_VER, prompt), algo = "sha256")
  path <- file.path(DIR_CACHE_SWIPE, paste0(key, ".json"))
  cached <- file.exists(path)
  if (!cached) {
    n <- if (is.null(calls$n)) 0L else calls$n
    if (!live || n >= SWIPE_MAX_CALLS)
      return(tibble::tibble(ai_summary = NA_character_, ai_quote = NA_character_, quote_ok = NA, cached = FALSE, skipped = TRUE))
    dir.create(DIR_CACHE_SWIPE, showWarnings = FALSE, recursive = TRUE)
    writeLines(chat_fn(prompt), path, useBytes = TRUE)    # cache before use
    calls$n <- n + 1L
  }
  raw <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  p <- tryCatch(jsonlite::fromJSON(raw), error = function(e) list())
  s <- str_squish(unent(as.character(p$ai_summary %||% ""))) |> str_remove("(?i),? (with|and) no [^.]*(mentioned|specified|stated)[^.]*(?=\\.)"); q <- str_squish(str_remove_all(unent(as.character(p$ai_quote %||% "")), "^[\"' ]+|[\"' .]+$"))
  ok <- nzchar(s) && nzchar(q) && str_detect(text, fixed(normalize_text(q), ignore_case = TRUE))
  tibble::tibble(ai_summary = if (ok) s else NA_character_, ai_quote = if (ok) normalize_text(q) else NA_character_,
                 quote_ok = ok, cached = cached, skipped = FALSE)
}

run_swipe_summary <- function(payload_path = here::here("data", "processed", "payload.json"),
                              extract_path = here::here("data", "processed", "opportunities.csv"),
                              live = identical(Sys.getenv("SWIPE_SUMMARY_LIVE"), "yes"), chat_fn = aoai_chat,
                              limit = Inf) {
  ids <- jsonlite::read_json(payload_path, simplifyVector = TRUE)$rows |> arrange(!in_top10, rank) |> distinct(opp_id)
  ex <- read_csv(extract_path, col_types = cols(.default = "c"), show_col_types = FALSE) |>
    distinct(opp_id, .keep_all = TRUE) |>
    transmute(opp_id, title, text = str_squish(paste(summary, eligibility_text)))
  items <- ids |> inner_join(ex, by = "opp_id") |> filter(nzchar(text)) |> head(limit)
  calls <- new.env(); calls$n <- 0L
  res <- purrr::map_dfr(seq_len(nrow(items)), function(i)
    dplyr::bind_cols(tibble::tibble(opp_id = items$opp_id[i]), summarize_one(items$title[i], items$text[i], live, calls, chat_fn)))
  message(sprintf("%d items; %d summarized with a verified quote (cache %d, live %d); %d quote failures; %d skipped (no cache, live off or cap %d)",
    nrow(items), sum(res$quote_ok %in% TRUE), sum(res$cached & !res$skipped), calls$n, sum(res$quote_ok %in% FALSE), sum(res$skipped), SWIPE_MAX_CALLS))
  res
}

if (sys.nframe() == 0) {
  out <- run_swipe_summary(limit = as.numeric(Sys.getenv("SWIPE_LIMIT", "Inf")))
  if (nrow(out) && !all(out$skipped)) write_csv(out |> filter(!skipped) |> select(-skipped), here::here("data", "processed", "swipe_summary.csv"))
}

# helpers_llm.R: label text with a free local model (Ollama), with a cache.
#
# The model only labels, and every non-negative label must come with a quote copied
# from the source text; a label whose quote is not found in the text is thrown out.
# The model never ranks, scores or decides. Responses are cached to
# data/cache/llm/<sha256>.json, keyed by model + prompt version + the exact prompt, so a
# rerun never re-queries and never changes a label.
#
# Splitting the work across laptops: pass shard = c(k, n) to label_items() on laptop k
# of n. Each laptop writes its own cache files; copy data/cache/llm/ between machines
# (Drive or git) and every laptop sees every label. Requires 00_config.R.

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(purrr); library(tibble)
  library(httr2); library(jsonlite); library(digest)
})

normalize_text <- function(x) str_squish(str_replace_all(x, "[‘’“”]", "'"))

ollama_ready <- function(model = LLM_MODEL) {
  tags <- tryCatch(
    httr2::request(paste0(OLLAMA_URL, "/api/tags")) |> httr2::req_timeout(5) |>
      httr2::req_perform() |> httr2::resp_body_json(),
    error = function(e) NULL)
  if (is.null(tags)) stop("Ollama is not running at ", OLLAMA_URL, ". Start it with `ollama serve`.")
  have <- vapply(tags$models, function(m) m$name, character(1))
  if (!any(startsWith(have, model))) stop("Model ", model, " not installed. Run `ollama pull ", model, "`.")
  invisible(TRUE)
}

ollama_chat <- function(prompt, model = LLM_MODEL) {
  resp <- httr2::request(paste0(OLLAMA_URL, "/api/chat")) |>
    httr2::req_timeout(LLM_TIMEOUT_SEC) |>
    httr2::req_body_json(list(model = model, stream = FALSE, format = "json",
      options = list(temperature = 0, seed = LLM_SEED),
      messages = list(list(role = "user", content = prompt)))) |>
    httr2::req_perform() |> httr2::resp_body_json()
  resp$message$content
}

build_prompt <- function(question, levels, text) {
  paste0(
    "Answer one question about the text below.\n",
    "Question: ", question, "\n",
    "Allowed labels: ", paste(levels, collapse = ", "), ".\n",
    "The last label means the text gives no support. For any other label, you must copy ",
    "an exact quote from the text as evidence. Do not paraphrase. Do not use outside knowledge.\n",
    "Reply with JSON only: {\"label\": \"<label>\", \"evidence\": \"<exact quote or empty string>\"}\n\n",
    "TEXT:\n", text)
}

# Label one text. `.chat_fn` is injectable so tests never call the model.
llm_label <- function(text, question, levels, .chat_fn = ollama_chat) {
  prompt <- build_prompt(question, levels, text)
  key <- digest::digest(list(LLM_MODEL, LLM_PROMPT_VERSION, prompt), algo = "sha256")
  path <- file.path(DIR_CACHE_LLM, paste0(key, ".json"))
  cached <- file.exists(path)
  raw <- if (cached) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else {
    dir.create(DIR_CACHE_LLM, showWarnings = FALSE, recursive = TRUE)
    out <- .chat_fn(prompt)
    writeLines(out, path, useBytes = TRUE)
    out
  }
  parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(e) list(label = NA, evidence = ""))
  label <- as.character(parsed$label %||% NA)
  evidence <- as.character(parsed$evidence %||% "")
  none <- levels[length(levels)]
  bad_label <- is.na(label) || !label %in% levels
  quote_ok <- !bad_label && (label == none || (nzchar(evidence) &&
    str_detect(normalize_text(text), fixed(normalize_text(evidence), ignore_case = TRUE))))
  # A label with no verifiable quote is not trusted: it falls back to the "none" level.
  tibble(label = if (quote_ok) label else none,
         evidence = if (quote_ok && label != none) evidence else NA_character_,
         evidence_ok = quote_ok, cached = cached)
}

# Label every row of `df`. Returns one row per input item with the label, quote and flags.
label_items <- function(df, id_col, text_col, question, levels, shard = c(1L, 1L),
                        .chat_fn = ollama_chat) {
  ids <- df[[id_col]]
  keep <- ((seq_along(ids) - 1L) %% shard[2]) == (shard[1] - 1L)
  idx <- which(keep)
  map_dfr(idx, function(i) {
    text <- as.character(df[[text_col]][i])
    if (is.na(text) || !nzchar(text))
      return(tibble(id = ids[i], label = levels[length(levels)], evidence = NA_character_,
                    evidence_ok = TRUE, cached = TRUE))
    bind_cols(tibble(id = ids[i]), llm_label(text, question, levels, .chat_fn))
  })
}

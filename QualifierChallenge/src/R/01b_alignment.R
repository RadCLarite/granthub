# 01b_alignment.R — how well each opportunity's abstract aligns with each agency's
# strategic plan. Two independent scores, reported side by side and never averaged:
#   1. Lexical: BM25 of the abstract against each plan row (pure R, transparent).
#   2. Semantic: cosine similarity of local embeddings (Ollama, nomic-embed-text).
# For each score and agency: the best-matching plan row and its percentile among
# all 1,662 opportunities. Embeddings are cached by content hash, so a re-run makes
# no model calls. Requires 00_config.R and 01_load_clean.R.

suppressPackageStartupMessages({ library(httr2); library(jsonlite); library(digest) })

# ---- Plan rows -------------------------------------------------------------------

load_priorities <- function() {
  imap_dfr(PRIORITY_FILES, function(f, agency) {
    readr::read_csv(file.path(DIR_MANUAL, f), col_types = readr::cols(.default = "c"))
  }) |>
    mutate(page = as.integer(page), human_verified = safe_false(human_verified),
           alignable = safe_false(alignable))
}

# Every plan row must be found on the PDF page it cites. Plans laid out as tables
# interleave columns line by line, so the check is an in-order word match: at least
# PLAN_VERIFY_MIN_RATIO of the row's words must appear in order on the cited page
# (or spill onto the next one). Returns match_ratio and on_page per row.
PRIORITY_PDFS <- c(DHHS = "NCDHHS 2023-25 Strategic Plan.pdf", DMVA = "NCDMVA_StratPlan25-29_2025.09.03.pdf")
PLAN_VERIFY_MIN_RATIO <- 0.9

# Each word is looked for only within the next `window` words after the previous
# match, so one unmatched word (a PDF typo such as "partnerswho") cannot jump the
# search to a far-away page and fail every word after it.
in_order_ratio <- function(needle, hay, window = 40L) {
  start <- match(needle[1], hay)
  if (is.na(start)) start <- 1L
  best <- 0
  for (s0 in which(hay == needle[1]) %||% start) {
    j <- s0; hit <- 0L
    for (w in needle) {
      if (j > length(hay)) break
      seg <- hay[j:min(length(hay), j + window)]
      k <- match(w, seg)
      if (!is.na(k)) { hit <- hit + 1L; j <- j + k }
    }
    best <- max(best, hit / length(needle))
  }
  best
}

verify_priorities_against_pdf <- function(p = load_priorities()) {
  words <- function(x) {
    x <- str_to_lower(iconv(x, to = "ASCII//TRANSLIT"))
    w <- unlist(str_split(str_replace_all(x, "[^a-z0-9]+", " "), " "))
    w[nzchar(w)]
  }
  pages <- map(PRIORITY_PDFS, ~ suppressMessages(pdftools::pdf_text(file.path(DIR_RAW_PLANS, .x))))
  p |> mutate(
    match_ratio = pmap_dbl(list(agency, text, page), function(a, t, pg) {
      pp <- pages[[a]]; in_order_ratio(words(t), words(paste(pp[pg], if (pg < length(pp)) pp[pg + 1] else "")))
    }),
    on_page = match_ratio >= PLAN_VERIFY_MIN_RATIO)
}

alignable_priorities <- function(p = load_priorities()) {
  if (ALIGN_EXCLUDE_INTERNAL_OPS) p |> filter(alignable) else p
}

# ---- Opportunity text --------------------------------------------------------------

alignment_text <- function(g) {
  str_sub(str_squish(str_c(coalesce(g$opportunity_title, ""), ". ", g$summary_text)),
          1, EMBED_MAX_CHARS)
}

# ---- BM25 -----------------------------------------------------------------------------

bm25_tokens <- function(x) {
  toks <- str_split(str_to_lower(str_replace_all(x, "[^A-Za-z0-9]+", " ")), "\\s+")
  map(toks, ~ .x[nchar(.x) > 2 & !.x %in% BM25_STOPWORDS])
}

# Scores every query (opportunity) against every document (plan row).
bm25_matrix <- function(queries, docs) {
  q_tok <- bm25_tokens(queries)
  d_tok <- bm25_tokens(docs)
  dl <- lengths(d_tok); avgdl <- mean(dl); n_docs <- length(d_tok)
  vocab <- unique(unlist(d_tok))
  tf <- sapply(d_tok, function(t) tabulate(match(t, vocab), nbins = length(vocab)))
  tf <- matrix(tf, nrow = length(vocab))
  df <- rowSums(tf > 0)
  idf <- log(1 + (n_docs - df + 0.5) / (df + 0.5))
  norm <- BM25_K1 * (1 - BM25_B + BM25_B * dl / avgdl)
  w <- (tf * (BM25_K1 + 1)) / sweep(tf, 2, norm, "+")
  w[is.nan(w)] <- 0
  w <- w * idf
  t(sapply(q_tok, function(t) {
    idx <- unique(match(t, vocab)); idx <- idx[!is.na(idx)]
    if (length(idx) == 0) return(rep(0, n_docs))
    colSums(w[idx, , drop = FALSE])
  }))
}

# ---- Embeddings (Ollama, cached by content hash) ---------------------------------------

embed_cache_path <- function(text, prefix) {
  key <- digest(paste(LLM_EMBED_MODEL, prefix, text, sep = "␟"), algo = "sha256", serialize = FALSE)
  file.path(DIR_CACHE_LLM, "embed", paste0(key, ".json"))
}

ollama_embed <- function(texts) {
  resp <- request(paste0(OLLAMA_URL, "/api/embed")) |>
    req_body_json(list(model = LLM_EMBED_MODEL, input = as.list(texts), truncate = TRUE)) |>
    req_timeout(600) |> req_perform() |> resp_body_json()
  map(resp$embeddings, unlist)
}

embed_cached <- function(texts, prefix) {
  paths <- map_chr(texts, embed_cache_path, prefix = prefix)
  todo <- which(!file.exists(paths))
  if (length(todo) > 0) {
    message("Embedding ", length(todo), " new texts with ", LLM_EMBED_MODEL)
    dir.create(dirname(paths[1]), showWarnings = FALSE, recursive = TRUE)
    for (chunk in split(todo, ceiling(seq_along(todo) / EMBED_BATCH_SIZE))) {
      vecs <- ollama_embed(paste0(prefix, texts[chunk]))
      walk2(chunk, vecs, ~ writeLines(toJSON(.y, digits = NA), paths[.x]))
    }
  }
  do.call(rbind, map(paths, ~ unlist(fromJSON(.x))))
}

cosine_matrix <- function(a, b) {
  a <- a / sqrt(rowSums(a^2)); b <- b / sqrt(rowSums(b^2))
  a %*% t(b)
}

# ---- Scores ------------------------------------------------------------------------------

best_per_row <- function(m, ids) {
  j <- max.col(m, ties.method = "first")
  tibble(score = m[cbind(seq_len(nrow(m)), j)], best_id = ids[j])
}

compute_alignment <- function(g, priorities = alignable_priorities()) {
  opp_text <- alignment_text(g)
  opp_emb <- embed_cached(opp_text, "search_query: ")
  map_dfr(unique(priorities$agency), function(ag) {
    pr <- priorities |> filter(agency == ag)
    pr_emb <- embed_cached(pr$text, "search_document: ")
    emb <- best_per_row(cosine_matrix(opp_emb, pr_emb), pr$priority_id)
    lex <- best_per_row(bm25_matrix(opp_text, pr$text), pr$priority_id)
    tibble(
      opportunity_number = g$opportunity_number,
      agency = ag,
      emb_score = emb$score, emb_best_id = emb$best_id,
      emb_pct = dplyr::percent_rank(emb$score),
      bm25_score = lex$score, bm25_best_id = lex$best_id,
      bm25_pct = dplyr::percent_rank(lex$score)
    )
  })
}

# ---- Standalone run -------------------------------------------------------------------
if (sys.nframe() == 0L) {
  here::i_am("src/R/01b_alignment.R")
  source(here::here("src", "R", "00_config.R"))
  source(here::here("src", "R", "01_load_clean.R"))
  alignment <- compute_alignment(grants)
  saveRDS(alignment, file.path(DIR_PROCESSED, "alignment.rds"))
  message("Alignment rows: ", nrow(alignment))
}

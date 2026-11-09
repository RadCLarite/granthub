# keyword_baseline.R  (source this file; it defines functions and runs nothing)
#
# WHAT THIS IS: the simple comparison method. It mimics what a person does with a
# keyword search: take the words in an agency's goals, and count how many of those
# words show up in each opportunity's title and summary.
#
# WHAT THIS IS NOT: it is NOT our ranker. It exists only so we can say what our
# ranker finds that a plain keyword search misses.
#
# KNOWN WEAKNESS (on purpose, not a bug): generic words produce false positives
# (for example "water", "school", "resources" appear in many unrelated notices),
# and a notice that uses different words than the plan is missed entirely.
# We drop a stopword list and a short list of very generic words, but any list
# like this is a judgment call. Edit GENERIC_WORDS below if Kent wants it stricter.
#
# Deterministic: no randomness. Ties are broken by opp_id (text order).

suppressMessages(library(data.table))

# Pool statuses: open items plus Federal Register notices (decision 9). Closed items are NOT in the pool.
# Decision 1 says closed items are scored in the product; whether the pool should include them is open (Kent decides).
POOL_STATUSES <- c("posted", "forecasted", "notice")

STOPWORDS <- c("a","about","above","after","again","all","also","an","and","any","are","as","at",
  "be","because","been","before","being","between","both","but","by","can","each","for","from",
  "had","has","have","how","if","in","into","is","it","its","more","most","not","of","on","or",
  "other","our","out","over","own","same","so","some such","than","that","the","their","them",
  "then","there","these","they","this those","through","to","too","under","until","up","very",
  "was","we","were","what","when","where","which","while","who","will","with","within","would","you","your")
STOPWORDS <- unlist(strsplit(STOPWORDS, " "))

# Very generic words in plans and in grant notices alike. Dropping them cuts false
# positives but is a judgment call.
GENERIC_WORDS <- c("north","carolina","state","states","department","program","programs","public",
  "service","services","improve","ensure","support","strengthen","across","throughout","advance",
  "expand","enhance","leading","lead","support","excellence","operational","operations","efficiency",
  "efficiencies","collaboration","customer","community","communities","local","new","help","provide",
  "work","using","use","plan","goal","goals","each","every","people","system","systems","national",
  "federal","field","future","serve","working","next","life","fully","change","reflect","integrate","dncr","pathway","grant","grants","funding","award","awards","project","projects","applicants","application",
  "information","development","management","include","includes","including","based")

# Light normalising so "schools" matches "school". Crude on purpose.
.kb_tokens <- function(x) {
  x <- tolower(gsub("<[^>]+>", " ", x))
  x <- gsub("[^a-z]+", " ", x)
  tok <- unlist(strsplit(x, " ", fixed = TRUE), use.names = FALSE)
  tok <- tok[nchar(tok) > 0]
  ifelse(nchar(tok) > 4 & grepl("s$", tok) & !grepl("ss$", tok), sub("s$", "", tok), tok)
}

# Terms for one agency, using the exact agency label from agency_goal_summaries.csv.
# Uses goal_text_exact, plus goal_statement when it is not blank.
agency_terms <- function(agency_label, goals) {
  # NB: do not name the argument "agency": data.table would read it as the column.
  g <- as.data.frame(goals)
  g <- g[g$agency == agency_label, ]
  if (nrow(g) == 0) stop("Agency not found in goals file (use the exact label): ", agency_label)
  txt <- c(g$goal_text_exact, g$goal_statement)
  txt <- txt[!is.na(txt) & nzchar(trimws(txt))]
  tok <- .kb_tokens(txt)
  drop <- .kb_tokens(c(STOPWORDS, GENERIC_WORDS))
  tok <- tok[nchar(tok) >= 4 & !(tok %in% c(STOPWORDS, GENERIC_WORDS, drop))]
  sort(unique(tok))
}

# Score every row of `opps` for one agency's terms.
# Returns a data.table: opp_id, kw_score (distinct terms matched in title+summary),
# kw_hits (the matched terms; for the hidden key only, never for the label sheet),
# kw_rank (1 = best; ties broken by opp_id so reruns match).
keyword_baseline <- function(opps, terms) {
  txt <- paste(opps$title, opps$summary)
  hits <- lapply(txt, function(t) intersect(terms, .kb_tokens(t)))
  out <- data.table(opp_id = as.character(opps$opp_id),
                    kw_score = vapply(hits, length, integer(1)),
                    kw_hits = vapply(hits, paste, character(1), collapse = "|"))
  setorder(out, -kw_score, opp_id)
  out[, kw_rank := seq_len(.N)]
  out[]
}

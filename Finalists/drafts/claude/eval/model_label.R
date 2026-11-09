# model_label.R -- label the evaluation pool with the local Ollama model (decision B).
#
# Run from anywhere inside Finalists:
#   Rscript drafts/claude/eval/model_label.R stage=validate hand=/path/to/hand_label_items.xlsx
#   Rscript drafts/claude/eval/model_label.R stage=full            # only after validate passes
#
# stage=validate: labels the 60 hand-labelled items, compares with the hand labels, writes
#   model_labels/validate_labels.csv, agreement.csv, agreement_report.md, gate.txt (PASS/FAIL).
# stage=full: labels EVERY pool row (posted, forecasted, notice) for the 3 agencies. Refuses
#   unless gate.txt says PASS (add force=1 to override; report the override).
#
# The model only labels, and every non-"not relevant" label needs a quote found in the text
# (helpers_llm.R); a label without a verifiable quote becomes "not relevant". It never
# sees the keyword score, rank, stratum or hand labels. Responses are cached in
# data/cache/llm/, so a rerun resumes and never changes a label.
# Gate (decision B): model catches >= 80% of hand "relevant" AND Cohen's kappa >= 0.6 on
# (relevant + maybe) vs not relevant.

suppressPackageStartupMessages({ library(data.table); library(openxlsx); library(httr2); library(jsonlite) })

args <- commandArgs(TRUE)
arg <- function(k, d = NULL) { m <- grep(paste0("^", k, "="), args, value = TRUE); if (length(m)) sub(paste0("^", k, "="), "", m[1]) else d }
stage <- arg("stage", "validate")
stopifnot(stage %in% c("validate", "full"))

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
here_dir <- dirname(normalizePath(script))
repo <- normalizePath(file.path(here_dir, "..", "..", ".."))
setwd(file.path(repo, "src"))
source("R/00_config.R"); source("R/helpers_llm.R")
if (nzchar(Sys.getenv("OLLAMA_URL"))) OLLAMA_URL <- Sys.getenv("OLLAMA_URL")   # point at a second server for parallel runs
LLM_PROMPT_VERSION <- "evalpool-v3"      # separate cache namespace from other prompts
LLM_NUM_CTX <- 8192L                      # ollama's default window would truncate long notices
MAX_TEXT_CHARS <- 6000L

out_dir <- file.path(here_dir, "model_labels"); dir.create(out_dir, showWarnings = FALSE)
AGENCIES <- c("Department of Public Schools", "Department of Environmental Quality", "Department of Health and Human Services")
LEVELS <- c("relevant", "maybe", "not relevant")
POOL_STATUSES <- c("posted", "forecasted", "notice")

opps  <- fread(file.path(repo, "data", "processed", "opportunities.csv"), colClasses = list(character = c("opp_id", "opp_number")))
goals <- fread(file.path(repo, "src", "docs", "agency_goal_summaries.csv"))

clean_text <- function(x) {
  x <- gsub("&amp;", "&", x, fixed = TRUE); x <- gsub("&#8217;|&#39;|&rsquo;", "'", x)
  x <- gsub("&#8211;|&ndash;", "-", x); x <- gsub("&quot;|&#8220;|&#8221;", "\"", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE); trimws(gsub("\\s+", " ", x))
}
nz <- function(x) { x <- as.character(x); ifelse(is.na(x) | !nzchar(trimws(x)), "unknown", x) }

question_for <- function(ag) {
  g <- goals[agency == ag]
  gt <- unique(trimws(c(g$goal_text_exact, g$goal_statement))); gt <- gt[!is.na(gt) & nzchar(gt)]
  paste0("You are screening grant opportunities for the grant writer at the North Carolina ", ag, ". ",
         "The agency's plan goals are:\n- ", paste(gt, collapse = "\n- "), "\n",
         "Judge the TOPIC against the agency's goals first. Labels:\n",
         "- relevant: the topic clearly matches a named goal and the money could fund the agency's own services or operations.\n",
         "- maybe: the topic clearly matches a specific named goal, but it is unclear whether a state agency can apply (the notice names colleges, universities, tribes, or says only 'see Section 2'). A broad sector overlap alone (health, science, education, economic development) is NOT enough for 'maybe'.\n",
         "- not relevant: everything else, including: (a) topics in another agency's domain (medical or health research for a schools agency; education programs for an environmental agency); (b) laboratory, biomedical or basic research aimed at scientists, even when the topic is health (state agencies fund services, not lab research); (c) awards to individuals or existing grantees (fellowships, trainee or training-program grants such as T32, postdoctoral awards, administrative supplements to existing grants); (d) programs whose work or applicants are outside the United States (embassy funds, overseas studies); (e) no link to any goal.\n",
         "For 'relevant' or 'maybe', evidence must be ONE short exact quote (under 25 words) copied character for character from the Title or Summary lines. Do not use ellipses or edit the quote.")
}
item_text <- function(r) {
  substr(paste0("Title: ", clean_text(r$title), "\nFunder: ", clean_text(nz(r$agency_funder_name)), "\nStatus: ", r$status,
                "\nClose date: ", nz(r$close_date), "\nAward ceiling: ", nz(r$award_ceiling),
                "\nApplicant types: ", clean_text(nz(r$applicant_types_named)),
                "\nSummary: ", clean_text(nz(r$summary)),
                "\nEligibility: ", clean_text(nz(r$eligibility_text))), 1, MAX_TEXT_CHARS)
}

chat <- function(prompt, model = LLM_MODEL) {
  resp <- request(paste0(OLLAMA_URL, "/api/chat")) |> req_timeout(LLM_TIMEOUT_SEC) |>
    req_body_json(list(model = model, stream = FALSE, format = "json",
      options = list(temperature = 0, seed = LLM_SEED, num_ctx = LLM_NUM_CTX),
      messages = list(list(role = "user", content = prompt)))) |>
    req_perform() |> resp_body_json()
  resp$message$content
}

label_rows <- function(rows, ag) {
  q <- question_for(ag); n <- nrow(rows)
  res <- lapply(seq_len(n), function(i) {
    if (i %% 10 == 1 || i == n) message(sprintf("[%s] %d/%d", ag, i, n))
    r <- llm_label(item_text(rows[i]), q, LEVELS, .chat_fn = chat)
    data.table(agency = ag, opp_id = rows$opp_id[i], opp_number = rows$opp_number[i], title = clean_text(rows$title[i]),
               model_label = r$label, evidence = r$evidence, evidence_ok = r$evidence_ok, cached = r$cached)
  })
  rbindlist(res)
}

ollama_ready(LLM_MODEL)

if (stage == "validate") {
  hand_file <- arg("hand", path.expand("~/Downloads/hand_label_items.xlsx"))
  tabs <- c(PublicSchools = AGENCIES[1], EnvQuality = AGENCIES[2], DHHS = AGENCIES[3])
  # Join by (agency, item_no) through the key, because opp_number is blank or repeated for some rows.
  # Only opp_id is taken from the key; strata, ranks and keyword hits never reach the model.
  key <- fread(file.path(here_dir, "sheets", "key_hidden_DO_NOT_SHARE.csv"), colClasses = list(character = c("opp_id", "opp_number")))
  hand <- rbindlist(lapply(names(tabs), function(s) {
    d <- as.data.table(read.xlsx(hand_file, s)); d[, agency := tabs[[s]]]
    d[, .(agency, item_no = as.integer(item_no), sheet_title = title, hand_label = trimws(tolower(label)))]
  }))
  stopifnot(nrow(hand) == 60, all(hand$hand_label %in% LEVELS))
  hand <- merge(hand, key[, .(agency, item_no, opp_id)], by = c("agency", "item_no"))
  m <- merge(hand, opps[, !"opp_number"], by = "opp_id", suffixes = c("", "_funder"))
  setnames(m, "agency_funder", "agency_funder_name", skip_absent = TRUE)
  stopifnot(nrow(m) == 60, !anyDuplicated(m$opp_id) || TRUE)
  # label_rows() reads rows$agency as funder text; pass funder under its own name
  m[, opp_number := key$opp_number[match(paste(agency, item_no), paste(key$agency, key$item_no))]]
  lab <- rbindlist(lapply(AGENCIES, function(ag) label_rows(m[agency == ag], ag)))
  both <- merge(lab, m[, .(agency, opp_id, item_no, hand_label)], by = c("agency", "opp_id"))
  fwrite(both, file.path(out_dir, "validate_labels.csv"))

  kappa2 <- function(a, b) { po <- mean(a == b); pe <- mean(a) * mean(b) + mean(!a) * mean(!b); if (pe == 1) NA_real_ else (po - pe) / (1 - pe) }
  metrics <- function(d) {
    h <- d$hand_label == "relevant"; hb <- d$hand_label != "not relevant"; mb <- d$model_label != "not relevant"
    data.table(n = nrow(d), hand_relevant = sum(h), hand_rel_or_maybe = sum(hb),
      recall_relevant_by_model_relevant = if (sum(h)) mean(d$model_label[h] == "relevant") else NA_real_,
      recall_relevant_by_model_rel_or_maybe = if (sum(h)) mean(d$model_label[h] != "not relevant") else NA_real_,
      kappa_binary = kappa2(hb, mb), exact_agreement_3way = mean(d$hand_label == d$model_label))
  }
  ag_tab <- both[, metrics(.SD), by = agency]; all_tab <- cbind(agency = "ALL", metrics(both))
  agree <- rbind(ag_tab, all_tab); fwrite(agree, file.path(out_dir, "agreement.csv"))
  conf <- as.data.frame.matrix(table(hand = factor(both$hand_label, LEVELS), model = factor(both$model_label, LEVELS)))
  recall_gate <- all_tab$recall_relevant_by_model_rel_or_maybe   # model flags it at all (relevant or maybe)
  pass <- isTRUE(recall_gate >= 0.8) && isTRUE(all_tab$kappa_binary >= 0.6)
  writeLines(if (pass) "PASS" else "FAIL", file.path(out_dir, "gate.txt"))
  rep <- c("# Model vs hand labels (validation)", "",
    paste0("Model: ", LLM_MODEL, ", prompt ", LLM_PROMPT_VERSION, ", temperature 0. Hand labels: one labeler (Kent), so this is agreement with one person, not ground truth."), "",
    paste0("Gate (decision B): recall of hand 'relevant' >= 0.80 and binary kappa >= 0.60. Result: **", if (pass) "PASS" else "FAIL", "**."),
    "Recall is counted when the model says relevant OR maybe on a hand-relevant item; the stricter model-'relevant'-only recall is in agreement.csv. Decision B does not say which; confirm.", "",
    "```", capture.output(print(as.data.frame(agree), digits = 3)), "", "Confusion (rows hand, columns model):", capture.output(print(conf)), "```", "",
    paste0("Quotes failing verification (forced to 'not relevant'): ", sum(!both$evidence_ok), " of ", nrow(both), "."),
    "Counts are tiny (60 items); one item moves recall by several points.")
  writeLines(rep, file.path(out_dir, "agreement_report.md"))
  cat(rep, sep = "\n")
} else if (stage == "full") {
  # One CSV per agency in model_labels/by_agency/ (finished agencies are skipped, so a rerun resumes).
  # machine=A|B|C|D|E picks that machine's agencies from agency_plan.csv; part=k/n runs every n-th one of them
  # (use it to run two or three processes on one machine). See HANDOFF_model_labeling_split.md.
  gate <- file.path(out_dir, "gate.txt")
  if (!identical(arg("force"), "1") && !(file.exists(gate) && readLines(gate, warn = FALSE)[1] == "PASS"))
    stop("Validation gate is not PASS (", gate, "). Fix the prompt or report hand labels only. force=1 overrides; say so in the report.")
  plan <- fread(file.path(out_dir, "agency_plan.csv"))[order(order)]
  mach <- arg("machine")
  if (is.null(mach) || !mach %in% plan$machine) stop("machine= must be one of: ", paste(sort(unique(plan$machine)), collapse = ", "))
  mine <- plan[machine == mach]
  pt <- as.integer(strsplit(arg("part", "1/1"), "/")[[1]])
  mine <- mine[((seq_len(.N) - 1L) %% pt[2]) == pt[1] - 1L]
  stopifnot(all(mine$agency %in% unique(goals$agency)))
  pool <- copy(opps)[status %in% POOL_STATUSES][, agency_funder_name := agency]
  dir.create(file.path(out_dir, "by_agency"), showWarnings = FALSE)
  # Every machine must label the same pool, or the per-agency files cannot be compared or merged.
  ref <- list.files(file.path(out_dir, "by_agency"), "\\.csv$", full.names = TRUE)
  if (length(ref)) {
    ref_ids <- fread(ref[1], select = "opp_id", colClasses = list(character = "opp_id"))$opp_id
    if (!setequal(ref_ids, pool$opp_id))
      stop("data/processed/opportunities.csv gives a different pool (", nrow(pool), " rows) from the finished labels (",
           length(ref_ids), " rows in ", basename(ref[1]), "). Do not pull a refreshed opportunities.csv mid-run; ask Kent.")
  }
  message(sprintf("Machine %s: %d agencies (%d already done, skipped)", mach, nrow(mine),
                  sum(file.exists(file.path(out_dir, "by_agency", paste0(gsub("^_|_$", "", gsub("[^a-z]+", "_", tolower(mine$agency))), ".csv"))))))
  for (ag in mine$agency) {
    f <- file.path(out_dir, "by_agency", paste0(gsub("^_|_$", "", gsub("[^a-z]+", "_", tolower(ag))), ".csv"))
    if (file.exists(f)) { message("skip (done): ", ag); next }
    lim <- suppressWarnings(as.integer(arg("limit", NA)))      # limit=N is for speed tests only
    if (!is.na(lim)) { t0 <- Sys.time(); label_rows(pool[seq_len(lim)], ag)
      message(sprintf("BENCH %s: %d items, %.1f s", ag, lim, as.numeric(difftime(Sys.time(), t0, units = "secs")))); next }
    res <- label_rows(pool, ag)
    fwrite(res, paste0(f, ".tmp")); file.rename(paste0(f, ".tmp"), f)   # file appears only when complete
    message("DONE ", ag)
  }
} else stop("stage must be validate or full")

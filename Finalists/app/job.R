# job.R: MODE=job. The daily refresh. Runs the scoring from cached data, checks the result against
# saturday/03_contract.md, stamps "data as of", and writes payload.json (local file and/or Blob).
# No model calls and no network calls except the Blob upload: the scoring reads only data/cache and
# data/processed. Fetching new opportunities from Grants.gov (02a to 03) is NOT part of this job.
#
# Settings (env vars; TODO move to 00_config.R, listed in Marco's handoff):
#   FINALISTS_DIR     root of the Finalists tree (holds Finalists.Rproj, src/, data/)
#                     default: the folder above app/ if it has src/, else /srv/finalists
#   RUN_PIPELINE      1 (default) runs src/R/13_daily_refresh.R (10_run_ranking + 11_build_payload) in FINALISTS_DIR/src;
#                     0 ships FINALISTS_DIR/data/processed/payload.json as it is (then data_as_of is NOT restamped)
#   JOB_OUT           also write the stamped payload to this local file (use a scratch path when testing)
#   JOB_DRY_RUN       1 (default): write nothing to Blob. 0: upload.
#   PAYLOAD_IN        payload to ship when not scoring (default: FINALISTS_DIR/data/processed/payload.json, then app/data/payload.json)
#   JOB_TODAY         YYYY-MM-DD override of "today" (tests only)
#   AS_OF_DATE        (set by this job from "today" before scoring; 00_config.R reads it) the scoring clock. REF_DATE stays frozen.
#   BLOB_WRITE_SAS    write SAS for the one blob; else managed identity (needs Storage Blob Data Contributor)
suppressPackageStartupMessages(library(jsonlite))

env <- function(k, d = "") { v <- Sys.getenv(k, ""); if (nzchar(v)) v else d }
msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "job:", ..., "\n")
die <- function(...) { msg(...); quit(status = 1) }

dry <- env("JOB_DRY_RUN", "1") != "0"
run_pipeline <- env("RUN_PIPELINE", "1") != "0"
blob <- "https://ffmdatateam15.blob.core.windows.net/ffm-data/payload.json"
Sys.setenv(TZ = env("TZ", "America/New_York"))
stamp_now <- Sys.time()
today <- if (nzchar(env("JOB_TODAY"))) as.Date(env("JOB_TODAY")) else as.Date(format(stamp_now, "%Y-%m-%d"))
iso <- function(t) sub("([+-]\\d\\d)(\\d\\d)$", "\\1:\\2", format(t, "%Y-%m-%dT%H:%M:%S%z"))

# ---- where the project is ---------------------------------------------------------------
script_dir <- tryCatch(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))),
                       error = function(e) getwd())
root <- env("FINALISTS_DIR", if (dir.exists(file.path(script_dir, "..", "src"))) normalizePath(file.path(script_dir, "..")) else "/srv/finalists")
have_tree <- dir.exists(file.path(root, "src", "R"))
# The app image (ffm-app) has no src/ and no scoring inputs, only a baked copy at data/payload.json.
# There the job cannot score: it checks and ships that copy (data_as_of is not restamped). Use the
# job image (Dockerfile.job) for real daily scoring.
if (!have_tree) { run_pipeline <- FALSE; msg("no src/R under", root, "; scoring skipped, shipping the baked payload") }
payload_path <- env("PAYLOAD_IN", file.path(root, "data", "processed", "payload.json"))
if (!file.exists(payload_path)) {
  for (alt in c(file.path(script_dir, "data", "payload.json"), "/srv/app/data/payload.json"))
    if (file.exists(alt)) { payload_path <- alt; break }
}

# ---- 1. score from cache ------------------------------------------------------------------
pipeline_ran <- FALSE
if (run_pipeline) {
  old <- setwd(file.path(root, "src")); on.exit(setwd(old), add = TRUE)
  Sys.setenv(AS_OF_DATE = format(today))   # scoring clock = today (or JOB_TODAY): expired rows leave and the Top 10 refills
  msg("scoring from cache as of", format(today), ": Rscript R/13_daily_refresh.R in", getwd())
  st <- system2("Rscript", "R/13_daily_refresh.R")
  if (st != 0) die("scoring failed, status", st, "; Blob file left as it is")
  pipeline_ran <- TRUE
}
if (!file.exists(payload_path)) die("no payload at", payload_path, "; nothing to ship")
p <- fromJSON(payload_path, simplifyVector = FALSE)

# ---- 2. refresh day-dependent fields -------------------------------------------------------
# When scoring ran above, 11_build_payload.R already counted days_left from AS_OF_DATE (= today) and refilled the
# Top 10, so this step finds nothing to drop. It stays as the safety net for a shipped file (RUN_PIPELINE=0 or the
# baked copy): recompute days_left against today, drop rows whose close date has passed (no refill without scoring),
# close the rank gaps and recount n_closing_soon. Fit scores and the order of the rest are untouched.
if (length(p$rows)) {
  dropped <- 0L
  for (i in seq_along(p$rows)) {
    cd <- p$rows[[i]]$close_date
    if (!is.null(cd) && !is.na(suppressWarnings(as.Date(cd)))) p$rows[[i]]$days_left <- as.integer(as.Date(cd) - today)
  }
  expired <- vapply(p$rows, function(r) !is.null(r$close_date) && !is.null(r$days_left) && r$days_left < 0L, TRUE)
  dropped <- sum(expired); p$rows <- p$rows[!expired]
  # opps (opportunity-level text stored once per opp_id) keeps only the opportunities that still have a row
  if (!is.null(p$opps)) p$opps <- p$opps[names(p$opps) %in% vapply(p$rows, function(r) as.character(r$opp_id), "")]
  key <- vapply(p$rows, function(r) paste(r$agency_id, isTRUE(r$in_top10), is.null(r$rank)), "")
  for (k in unique(key)) {
    idx <- which(key == k & !vapply(p$rows, function(r) is.null(r$rank), TRUE))
    if (length(idx)) {
      ord <- idx[order(vapply(idx, function(j) as.numeric(p$rows[[j]]$rank), 0))]
      for (n in seq_along(ord)) p$rows[[ord[n]]]$rank <- n
    }
  }
  # n_closing_soon was built at scoring time (11_build_payload.R); recount it on the surviving rows.
  if (!is.null(p$closing_soon_days)) {
    soon_ids <- vapply(Filter(function(r) isTRUE(r$in_top10) && !identical(r$status, "forecasted") && !is.null(r$days_left) &&
                                !is.na(r$days_left) && r$days_left >= 0L && r$days_left <= p$closing_soon_days, p$rows),
                       function(r) r$agency_id, "")
    for (i in seq_along(p$agencies)) p$agencies[[i]]$n_closing_soon <- as.integer(sum(soon_ids == p$agencies[[i]]$agency_id))
  }
  p$rows_dropped_expired <- as.integer(dropped)
  if (dropped) msg("dropped", dropped, "rows whose close date is before", format(today))
}

# ---- 3. contract check ----------------------------------------------------------------------
# A bad file must never replace a good one in Blob.
problems <- character()
add <- function(...) problems <<- c(problems, paste0(...))
miss <- setdiff(c("data_as_of", "window_days", "agencies", "rows"), names(p))
if (length(miss)) add("missing top-level: ", paste(miss, collapse = ", "))
if (!length(p$agencies)) add("no agencies")
if (!length(p$rows)) add("no rows")
if (!length(problems)) {
  ids <- vapply(p$agencies, function(a) a$agency_id, "")
  if (anyDuplicated(ids)) add("duplicate agency_id")
  need_a <- c("agency_id", "agency_name", "plan_files", "plan_stale", "plan_thin", "folded_from")
  nb <- sum(vapply(p$agencies, function(a) length(setdiff(need_a, names(a))) > 0, TRUE))
  if (nb) add(nb, " agencies miss required keys")
  need_r <- c("agency_id", "opp_id", "opp_number", "title", "status", "close_date", "days_left", "date_note",
              "fit_score", "rank", "in_top10", "eligibility", "elig_source", "elig_quote", "reader_label",
              "reader_quote", "goal_id", "goal_snippet", "opp_snippet", "cfda_list", "award_ceiling",
              "signature_tier", "tier_source", "nc_won_before", "url")
  bad <- sum(vapply(p$rows, function(r) length(setdiff(need_r, names(r))) > 0, TRUE))
  if (bad) add(bad, " rows miss contract keys")
  chk <- function(field, ok) {
    n <- sum(!vapply(p$rows, function(r) { v <- r[[field]]; !is.null(v) && v %in% ok }, TRUE))
    if (n) add(n, " rows have a bad ", field)
  }
  chk("status", c("posted", "forecasted", "notice"))
  chk("eligibility", c("yes", "no", "ask"))
  chk("signature_tier", c("writer", "supervisor", "leadership", "unknown"))
  stray <- sum(!vapply(p$rows, function(r) r$agency_id %in% ids, TRUE))
  if (stray) add(stray, " rows have an unknown agency_id")
  badfit <- sum(vapply(p$rows, function(r) !is.null(r$fit_score) && (!is.numeric(r$fit_score) || r$fit_score < 0 || r$fit_score > 1), TRUE))
  if (badfit) add(badfit, " rows have fit_score outside 0 to 1")
  zero_dl <- sum(vapply(p$rows, function(r) !is.null(r$close_date) && is.null(r$days_left), TRUE))
  if (zero_dl) add(zero_dl, " rows have a close_date but no days_left")
  top <- Filter(function(r) isTRUE(r$in_top10), p$rows)
  if (any(vapply(top, function(r) r$status == "forecasted", TRUE))) add("a forecast is flagged in_top10")
}
if (length(problems)) die("payload rejected:", paste(problems, collapse = "; "))

# ---- 4. stamp --------------------------------------------------------------------------------
# data_as_of moves only if scoring ran in this job. If the file was shipped as it was, keep its own stamp.
if (is.null(p$pipeline_as_of)) p$pipeline_as_of <- p$data_as_of
if (pipeline_ran) p$data_as_of <- iso(stamp_now)
p$shipped_at <- iso(stamp_now)
msg("payload ok:", length(p$agencies), "agencies,", length(p$rows), "rows, data_as_of", p$data_as_of)

out <- tempfile(fileext = ".json")
write_json(p, out, auto_unbox = TRUE, null = "null", na = "null", pretty = FALSE, digits = NA)
if (nzchar(env("JOB_OUT"))) {
  dir.create(dirname(env("JOB_OUT")), showWarnings = FALSE, recursive = TRUE)
  file.copy(out, env("JOB_OUT"), overwrite = TRUE); msg("wrote", env("JOB_OUT"))
}
if (dry) { msg("JOB_DRY_RUN is on: nothing written to Blob"); quit(status = 0) }

# ---- 5. upload -----------------------------------------------------------------------------
sas <- env("BLOB_WRITE_SAS")
hdr <- c("-H", shQuote("x-ms-blob-type: BlockBlob"), "-H", shQuote("Content-Type: application/json"),
         "-H", shQuote("x-ms-version: 2021-08-06"))
if (nzchar(sas)) {
  target <- paste0(blob, "?", sub("^\\?", "", sas))
} else {
  ep <- env("IDENTITY_ENDPOINT"); if (!nzchar(ep)) die("no BLOB_WRITE_SAS and no managed identity endpoint")
  tk <- paste(system2("curl", c("-s", "-H", shQuote(paste0("X-IDENTITY-HEADER: ", env("IDENTITY_HEADER"))),
              shQuote(paste0(ep, "?api-version=2019-08-01&resource=https://storage.azure.com/"))), stdout = TRUE), collapse = "")
  tok <- sub('.*"access_token":"([^"]+)".*', "\\1", tk)
  hdr <- c(hdr, "-H", shQuote(paste0("Authorization: Bearer ", tok)))
  target <- blob
}
code <- system2("curl", c("-s", "-o", "/dev/null", "-w", "%{http_code}", "-X", "PUT", hdr,
                "--data-binary", shQuote(paste0("@", out)), shQuote(target)), stdout = TRUE)
msg("upload HTTP status", code)
quit(status = if (identical(code, "201")) 0 else 1)

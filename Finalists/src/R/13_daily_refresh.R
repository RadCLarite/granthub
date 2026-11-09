# 13_daily_refresh.R: the scoring step of the daily job. Runs ranking then payload, from cache, and
# stops at the first failure so a bad run never reaches Blob. app/job.R then checks the shape, stamps
# "data as of" and ships payload.json (set PIPELINE_SCRIPT to this file).
# It does not fetch new opportunities: that is 02a to 03 (outside services, run by hand after approval).
# Run from Finalists/src:   Rscript R/13_daily_refresh.R
steps <- c("R/10_run_ranking.R", "R/11_build_payload.R")
for (s in steps) {
  cat("daily refresh:", s, "\n")
  if (system2("Rscript", s) != 0) { cat("daily refresh: FAILED at", s, "; payload.json left as it was\n"); quit(status = 1) }
}
cat("daily refresh: ok\n")

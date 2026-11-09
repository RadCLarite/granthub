# Daily job: what runs and what it needs

Scoring step (Kent): `Rscript R/13_daily_refresh.R`, run from the repo root. It runs `10_run_ranking.R` then `11_build_payload.R` from cache and stops at the first failure. `app/job.R` (Marco) then checks the payload shape, stamps "data as of" and ships it to Blob. Set `PIPELINE_SCRIPT=R/13_daily_refresh.R` for the job.

## What it does not do
- It does not fetch new opportunities. Fetching is `02a` to `03_merge_opportunities.R` (outside services, run by hand after approval). Until fetch is wired, a daily run re-scores the same data and the stamp must say so: `pipeline_as_of` keeps the pipeline's own date, `shipped_at` is the upload time.
- `PAYLOAD_AS_OF` now follows `AS_OF_DATE` (today in America/New_York, or env `AS_OF_DATE=YYYY-MM-DD`), stamped at 11:00 on that date, so reruns on the same day are identical. See `runbook.md` for what moves daily and what stays frozen.

## What the job image needs (today `app/Dockerfile` has only data.table, DT, jsonlite)
- R packages: `dplyr`, `stringr`, `Matrix`, `readr`, `here`, `jsonlite`.
- Files: `R/` (00_config, helpers_rank, score, helpers_io, 10, 11), `data/processed/opportunities.csv`, `data/processed/agency_plan_text/all/`, `data/manual/` (agency_map, criteria, program_map), `data/manual/agency_goal_summaries.csv`, and `granthub.Rproj` and `.here` so `here()` finds the root.
- If that is too heavy for the image, fall back to: run `13_daily_refresh.R` on a laptop, then trigger `job.R` to ship the file. Say so on the slide rather than claiming a cloud refresh.

## Check
Run `Rscript R/13_daily_refresh.R` twice; `payload.json` must be identical (md5).

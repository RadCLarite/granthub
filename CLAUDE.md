# grantHub: Federal Funds Matchmaker

R 4.5 pipeline plus one static page (`tool/matchmaker.html`) that ranks open federal grants against each NC agency's own strategic plan. Published on GitHub Pages by `.github/workflows/`. Read `README.md`, then `docs/pipeline.md` (how it works) and `docs/runbook.md` (daily job). `docs/REPO_MAP.md` lists every folder. `archive/` is history and is not used by the pipeline.

## Commands (run from the repo root; `here::here()` resolves through `.here`)
- Snapshot for tests (items.csv and ranking.csv are git-ignored): `AS_OF_DATE=2026-11-07 Rscript R/10_run_ranking.R && AS_OF_DATE=2026-11-07 Rscript R/11_build_payload.R`. `data/processed/payload.json` must stay byte-identical.
- Checks: `Rscript tests/run_tests.R` (expect zero failures), `Rscript R/check_facts.R` (49 of 49 rows pass), `python app/check_dupes.py`.
- CI-style job: `RUN_PIPELINE=1 JOB_DRY_RUN=1 JOB_OUT=/tmp/p.json Rscript app/job.R` (it rewrites `data/processed/payload.json` for today; rebuild the snapshot afterwards).
- Site: `sh app/build_pages.sh <outdir> data/processed/payload.json`, then `python -m http.server -d <outdir> 8000`.

## Constraints
- Every threshold and default lives in `R/00_config.R`. Tier rules live only in `signature_tier()` in `R/helpers_rank.R`. Tool numbers come from `payload.json`, not hard-coded JS.
- No invented figures: quoted numbers come from `docs/fact_sheet.md` and `data/manual/facts.csv`.
- The language model only labels text with a quoted piece of evidence. It never sets rank, eligibility or tier.
- Do not re-run outside-service scripts (`R/02*`, `R/03*` LLM labeling, ACS pull, `R/30`, `R/31`) casually; they call out for uncached items and some need keys.
- Never modify `data/raw/`. Do not edit `.Renviron` or `.RData`. Keep API keys out of every file.
- Log AI use in `AI_USAGE_LOG.md` and notable changes in `docs/improvement-log.md`.

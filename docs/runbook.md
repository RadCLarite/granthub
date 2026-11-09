# Runbook: Federal Funds Matchmaker on GitHub Pages (one page)

Owner: **[not yet named; Kent decides, criterion F1]**. Backup: [not yet named].
Status: written 2026-11-08. The workflows have not yet run on GitHub, so every "how to" below is from reading the files, not from a live run [unverified].

## What runs by itself
| What | When | Where |
|---|---|---|
| Re-score cached data, check the payload against `docs/contract.md`, rebuild the site, deploy | Daily 11:00 UTC (6 or 7 am Eastern), on every push to `main` that touches the tool or its data, and by hand | `.github/workflows/pages.yml` runs `app/job.R` (`RUN_PIPELINE=1`, `JOB_DRY_RUN=1`), then `app/build_pages.sh` |
| Fail if the live `payload.json` is more than 3 days old | Daily | `.github/workflows/freshness.yml` (repo variable `SITE_URL` overrides the assumed address) |
| Duplicate-function scan, site build and feed check on each pull request | On every pull request | `.github/workflows/checks.yml` |

### What moves daily, what stays frozen
- **Moves:** `AS_OF_DATE` in `R/00_config.R` (today in America/New_York; `app/job.R` sets it from its own "today", `JOB_TODAY` overrides it in tests; env `AS_OF_DATE=YYYY-MM-DD` overrides it for a reproducible run). It drives only the scoring and payload step: `days_left`, forecast dates that have passed, the runway score, which posted and notice grants are expired, `n_closing_soon`, and the `data_as_of` stamp (`PAYLOAD_AS_OF`, 11:00 on the as-of date). Expired grants leave each agency's Top 10 (and the hidden examples and counts) and the list refills from the next-ranked grants, at most 10 per agency. Same-day reruns give an identical `payload.json`.
- **Frozen:** `REF_DATE` (2026-11-06) in the same file. It is part of the fetch cache keys (`02b`, `02e`) and of fetch extraction and the backtests, so moving it would make the daily job call outside services. Do not change it without a person running the fetch scripts. The input data (`opportunities.csv`, caches) only changes when a person runs `02a` to `03`; until then the pool is the same posted grants minus those that have since closed.
- **Snapshot for tests:** `check_facts.R` and `tests/run_tests.R` pin `AS_OF_DATE` to `SNAPSHOT_AS_OF_DATE` (2026-11-07) and expect `payload.json` and `items.csv` built for that date (`AS_OF_DATE=2026-11-07 Rscript R/10_run_ranking.R`, then `R/11_build_payload.R`). After a daily job run on your machine, rebuild the snapshot before running them. `check_facts.R` stops with that instruction when the payload is stamped for another date. The committed `payload.json` is the snapshot build.
- `app/job.R` still drops rows whose close date has passed from a shipped file (`RUN_PIPELINE=0`) as a safety net; without scoring it cannot refill the Top 10.

The daily job calls no outside service and needs no secret. It re-scores what is already in the repo. It does **not** fetch new postings from Grants.gov; that step (`02*` to `03` scripts) is still run by a person and needs the API keys.

## How to see a failure
1. GitHub > Actions tab. A red run named "Deploy site to GitHub Pages" or "Freshness" is a failure. GitHub emails repo owners about failed scheduled runs.
2. Open the run, open the failed step, read the last 30 lines. Common causes: a missing R package in `pages.yml`, a payload that fails the contract check, or Pages not set to the GitHub Actions source.
3. A failed deploy leaves the previous site live. The tool shows a banner when its data is 3 or more days old.
4. Pages pauses scheduled workflows in a public repo after about 60 days with no activity [uncertain]. Any commit restarts them.

## How to rerun
- By hand: Actions > "Deploy site to GitHub Pages" > Run workflow (branch `main`).
- On your machine (R 4.5): from the repo root, `RUN_PIPELINE=1 JOB_DRY_RUN=1 JOB_OUT=/tmp/payload.json Rscript app/job.R`, then `sh app/build_pages.sh /tmp/site /tmp/payload.json`, then `python3 -m http.server -d /tmp/site 8000` and open `http://127.0.0.1:8000/matchmaker/`.
- Checks: from the repo root, `Rscript tests/run_tests.R` (expect "89 of 89 tests pass") and `Rscript R/check_facts.R` (expect "49 of 49 rows pass"). From the repo root, `python3 app/check_dupes.py`.

## Roll back
Revert the bad commit on a branch, open a pull request, merge. Or re-run an earlier green deploy from the Actions tab.

## Adding new postings
Run the data-collection scripts by hand with your own free Simpler.Grants.gov and SAM.gov keys in `api_keys.env` (git-ignored; copy `api_keys.env.example`). Commit the new caches and processed files on a branch and open a pull request. Never commit a key.

## One-time setup (a person with admin rights)
1. Settings > Pages > Source: **GitHub Actions**.
2. Set repository variable `SITE_URL` to the real address of the tool, and update the two assumed addresses (`FEEDBACK_ISSUE` in `tool/matchmaker.html`; `build_feeds.py`).
3. Run the deploy workflow once by hand and read any failure.

## Known limits
No accounts, no server, no per-user email, no usage measurement. Saved work lives in each visitor's browser; Export/Import moves it. Real use is not measured; the 7-day refresh record, the 20-grant spot check, the coordinator tests and the "worth a look" rating (criteria A3, B1, C, D) need people.

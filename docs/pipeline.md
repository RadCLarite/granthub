# grantHub (Federal Funds Matchmaker)

A tool that helps a North Carolina agency decide which open federal grants to look at first. Built by a team of five for the Solve-A-Thon 2026 Final Quest. The sponsor is the NC Office of State Budget and Management (OSBM).

Team: Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin, Noah Goldblatt.

Live copy on GitHub Pages: https://kapollol.github.io/granthub/matchmaker/ [uncertain: assumes Pages is enabled on KApolloL/granthub with Source: GitHub Actions]. It moved off Azure; the Azure files are kept as history (see "Legacy: deploy on Azure").

## What it does and for whom

The user is an agency grant coordinator. OSBM sponsors the tool and can compare agencies.

The coordinator picks an agency. The tool shows that agency's best-fitting open federal opportunities, a "Coming up" list of forecasted ones, and the ones it hid as clearly not eligible. Each row says why it matched: a snippet from the agency's own strategic plan, days left, and whether the agency looks eligible (Yes, No or Ask). The coordinator marks each row Pursue, Maybe or Pass and can export the view to CSV.

A person makes every decision. The tool only orders and explains. It does not apply for anything.

Scale today: 32 agencies and 1,576 open opportunities. See [docs/fact_sheet.md](fact_sheet.md) for these and all other numbers.

## Quick start

You need:
- R 4.5. The Docker images use R 4.4.2; both run the pipeline, but 4.5 is what the team used.
- Quarto is no longer needed; the old report template is in [archive/](../archive/).
- python3, only for the payload check in the deploy script.
- No API keys and no network. The caches are committed, so the ranking and tests read local files.

R packages (from the `library()` calls in the scripts below): here, dplyr, stringr, purrr, tibble, readr, tidyr, janitor, jsonlite, Matrix, digest, httr2. Some data scripts also use pdftools, readxl, sf and tigris. A missing package stops the run at the first load, so install first:

```r
install.packages(c("here","dplyr","stringr","purrr","tibble","readr","tidyr","janitor",
                   "jsonlite","Matrix","digest","httr2"))
```

Run everything from the repo root. Start with the ranking, then the two checks:

```bash
Rscript R/10_run_ranking.R     # writes data/processed/items.csv and ranking.csv, and outs/top_results.csv
Rscript tests/run_tests.R      # prints "89 of 89 tests pass"
Rscript R/check_facts.R        # prints "49 of 49 rows pass"
```

`items.csv` and `ranking.csv` are not in git, so run `10_run_ranking.R` first. Without it the tests fall back to the fake toy data in `data/example/` and fail.

To open the tool on your machine, serve the repo root and pass the payload path:

```bash
python3 -m http.server 8765
# open http://127.0.0.1:8765/tool/matchmaker.html?payload=/data/processed/payload.json
```

## Rebuild from scratch

On a clean clone, this order reproduces `data/processed/payload.json` byte for byte:

```bash
Rscript R/10_run_ranking.R
Rscript R/11_build_payload.R
Rscript tests/run_tests.R
Rscript R/check_facts.R
```

If you add data (new program obligations or agency budgets), rebuild in this order:

```bash
Rscript R/05e_federal_obligations.R   # federal spending per Assistance Listing, from the SAM.gov file in data/raw
Rscript R/05f_agency_budget.R         # agency General Fund base budget; downloads one OSBM PDF if it is not cached
Rscript R/10_run_ranking.R
Rscript R/11_build_payload.R
Rscript tests/run_tests.R
Rscript R/check_facts.R
```

Scripts `01a`, `02*`, `05a`, `05b`, `05c`, `30_notice_reader.R` and the LLM labeling scripts call outside services or need extra tools for anything not cached. Do not rerun them casually. They are the data-collection steps; their outputs are already committed in `data/processed/`.

## How it works

Four steps, all in R, all rule-based:

1. **Filter.** Hide opportunities that clearly exclude state agencies (applicant code, then fixed text rules). Unknown stays visible with an "Ask" badge. Criteria filters such as eligibility and overseas-post grants live in `data/manual/criteria.csv`.
2. **Score.** Fit is keyword overlap between the opportunity text and the agency's plan goals. Other criteria (award size, cost share, time to apply) are in the table with weights.
3. **Rank.** Open items go to the Top 10. Forecasted items go to "Coming up".
4. **Explain.** Each row carries the matched plan goal, a one-sentence note on how the score was reached, and a signature tier (who must sign off, from cost share and award size). Each row can also say **who it reaches**: a population group from keyword rules on the announcement (with the matching quote), and where that group lives in NC (counties, rural or urban, congressional districts), from the qualifier's ACS data. Display only; never enters the rank.

Rules to know:
- [data/manual/criteria.csv](../data/manual/criteria.csv) is the method. One row per rule, with a plain-language reason and a source. Change the table, not the code, where you can.
- Every threshold and default lives in [R/00_config.R](../R/00_config.R).
- An AI model may only label a notice, and only with a quote that is checked against the source text. It never decides a rank, an eligibility result or a tier. Today no model output is in the ranking.
- Award history ("NC has won this program before") is shown on the row. It is display only and never enters the score.
- The tool reads one file, `payload.json`. The format is in [docs/contract.md](contract.md). The tool takes its numbers from the payload, not from typed-in values.

## Repo map

| Path | What it is |
|---|---|
| [R/](../R/) | Numbered R pipeline. `00_config.R` holds settings. `02*` to `04` collect and merge data. `10_run_ranking.R` ranks, `11_build_payload.R` writes `payload.json`, `13_daily_refresh.R` runs 10 then 11. `helpers_rank.R` and `score.R` hold the ranking logic. `12_` and `20_` to `27_` are backtests. `check_facts.R` checks the published numbers. |
| [tool/](../tool/) | The one-page tool: `matchmaker.html`, plus `ranker.js`, `ui.js`, `styles.css`, `index.html` and a stub payload in `stub/`. |
| [tests/](../tests/) | `run_tests.R` is the runner. |
| [docs/](.) | [runbook](runbook.md), [fact_sheet](fact_sheet.md), [contract](contract.md), [daily_job](daily_job.md), [real_app_criteria](real_app_criteria.md), [REPO_MAP](REPO_MAP.md). |
| [app/](../app/) | The Azure container: `app.R` (Shiny), `job.R` (daily job), `Dockerfile`, `Dockerfile.job`, `entrypoint.sh`, `read_feedback.sh` (feedback form log), `pilot_scorecard.sh` (pilot measure from logged marks). |
| [data/raw/](../data/raw/) | Untouched inputs: 34 agency plan PDFs, the SAM.gov listings file, organizer files. Never modify. |
| [data/manual/](../data/manual/) | Hand-authored tables: `criteria.csv`, `agency_map.csv`, `program_map.csv`, `facts.csv`, `test_cases.csv`. |
| [data/cache/](../data/cache/) | Saved API, OCR and model responses, so reruns are free. |
| [data/processed/](../data/processed/) | Pipeline outputs, including `payload.json`. |
| [data/example/](../data/example/) | Fake toy data, used only when real files are missing. |
| [outs/](../outs/) | Generated files. Safe to delete. |
| [contract.md](contract.md) | The payload contract. |
| [archive/](../archive/) | Historical only, not used by the pipeline: competition planning, build-day notes, field notes, the organizer brief and rubric, and the qualifier round. See [archive/README.md](../archive/README.md). [requirements](REQUIREMENTS.md), [pilot plan](PILOT_PLAN.md) and [handover for a state developer](HANDOVER.md) stay in docs/. |
| [AI_USAGE_LOG.md](../AI_USAGE_LOG.md), [improvement-log.md](improvement-log.md) | The log of AI use and the log of changes made with AI help. |

## Deploy on GitHub Pages

One Pages site serves the repo: the qualifier site at `/` and this tool at `/matchmaker/`. `.github/workflows/pages.yml` runs on every push to `main` that touches the tool or its data, daily at 11:00 UTC, and on demand. It re-scores the cached data with `app/job.R` (`RUN_PIPELINE=1`, dry run, no outside call, no secret), checks the payload against `docs/contract.md`, then `app/build_pages.sh` assembles `index.html` and `payload.json`. If scoring or the check fails the run fails and the last deployment stays up. One-time setup: Settings > Pages > Source: GitHub Actions.

```bash
# needs R 4.5 with dplyr, ggplot2, here, httr2, janitor, jsonlite, Matrix, digest, purrr, readr, stringr, tibble
JOB_DRY_RUN=1 RUN_PIPELINE=1 JOB_OUT=/tmp/payload.json Rscript app/job.R
sh app/build_pages.sh /tmp/site /tmp/payload.json && python3 -m http.server -d /tmp/site 8000
```

Feedback: there is no server. The feedback dialog saves answers in the visitor's browser and offers an "Open a GitHub issue" button that opens a prefilled public issue (template `.github/ISSUE_TEMPLATE/feedback.yml`; needs a free GitHub account; `FEEDBACK_ISSUE` in `tool/matchmaker.html` holds the repo address, assumed, confirm). `app/read_feedback.sh` and `app/pilot_scorecard.sh` read the old Azure feedback and no longer apply.

Landing and tour: the home screen shows plain counts and a need-only county map (click a county to open the map tab on it; it shows where need is highest, not where a grant can be spent). The tour visits every tab: Find grants, My grants, Match an idea, County map, All agencies and How it works.

Readiness checklist: More > Readiness checklist. Eight items (SAM.gov, UEI, Grants.gov roles, signature chain, plan fit, match, staff time, closing date) with status, date checked and note, stored in the browser only. Dates are entered by the user; the tool does not verify them.

Workbench: More > Workbench. For grants marked Pursue: stage tracker, a time check (weeks left from the payload, hours entered by the user, a rule of thumb that is assumed and unvalidated), a closing-timeline chart for the chosen agency, a printable one-page summary, and a content library of reusable text. Browser-only.

Not built: calibrated win odds (no outcome data to calibrate on; any number would be invented), a source registry page (sources and as-of dates are already in How it works).

Saved work: Display menu has "Export my saved work" and "Import saved work". The file holds only `ffm_` browser keys and is the way to move work between browsers or people (no accounts, no shared workspace).

Feeds: `app/build_feeds.py` (called by `build_pages.sh`) writes an Atom feed and an ICS calendar per agency to `/matchmaker/feeds/` (index page there). Set `SITE_URL` if the Pages address differs from the assumed `https://kapollol.github.io/granthub/matchmaker/`. Feed readers and calendar apps poll these files; there is no per-user email.

Freshness: `.github/workflows/freshness.yml` loads the live `payload.json` daily and fails (GitHub emails the owners) if `data_as_of` is over 3 days old. The tool also shows a banner when its data is 3 or more days old. Set the repo variable `SITE_URL` if the Pages address differs.

PR checks: `.github/workflows/checks.yml` runs `app/check_dupes.py` (duplicate function names), builds the site and validates the feeds on every pull request. R tests are not run in CI yet; run `Rscript tests/run_tests.R` locally (89 of 89).

## Legacy: deploy on Azure (no longer used)

The app runs on Azure Container Apps. Names (resource group, registry `ffmacrteam15`, app `ffm-app`, storage `ffmdatateam15`) are in [archive/finalists/docs/azure_setup.md](../archive/finalists/docs/azure_setup.md).

How it fits together: `app/app.R` serves `matchmaker.html` at `/` and serves `/payload.json` from Blob Storage, with a copy baked into the image as fallback. No key is in the image.

The steps are in [archive/azure_era/deploy_azure.sh](../archive/azure_era/deploy_azure.sh). It is a dry run by default: it prints each command and runs none.

```bash
sh archive/azure_era/deploy_azure.sh                 # prints the plan only (Azure era; archived)
az login                               # a person signs in (Duo)
DEPLOY=yes sh archive/azure_era/deploy_azure.sh      # asks before every step
```

Steps in the script: stage assets and check no key is present, validate `payload.json` (needs python3), build the image with `az acr build`, upload `payload.json` to Blob, update the app, create the daily job, start the job once.

Status (Sat Nov 7, night): image `ffm-app:v24` is live, and the page it serves is byte-identical to `tool/matchmaker.html` on `main` at that time. Every deploy (image tag, revision, what changed) is logged in [archive/finalists/docs/azure_setup.md](../archive/finalists/docs/azure_setup.md).

## Daily refresh

`app/job.R` runs with `MODE=job`. It runs `R/13_daily_refresh.R` (rank, then build payload), checks the payload shape, stamps a "data as of" date, and uploads `payload.json` to Blob. `JOB_DRY_RUN` defaults to 1, which uploads nothing. Details and settings: [docs/daily_job.md](daily_job.md).

What it does not do: it does not fetch new postings. It re-scores the cached data. Fetching (`02*` to `03`) is still run by hand.

Status (Sun Nov 8): the job runs on image v36 and a run started by hand at 05:02 UTC succeeded. With the app image it skips scoring (no `R/` inside), checks the baked payload, drops rows whose close date has passed, and, because `JOB_DRY_RUN=1`, writes nothing. Its first scheduled run is 11:00 UTC Nov 8. Real daily re-scoring needs the job image (`Dockerfile.job`, not built yet) and a Blob write role; fetching new postings stays manual. Details in [archive/finalists/docs/azure_setup.md](../archive/finalists/docs/azure_setup.md).

## How to extend

**Add an agency.** Add the plan PDF and a row in `data/raw/agency_plans/MANIFEST.csv`, run `R/04_plan_text_extract.R`, add the agency to `data/manual/agency_map.csv`, and add goal rows with quotes to `data/manual/agency_goal_summaries.csv`. Then rebuild and run the tests. Step 4 uses macOS OCR for image-only pages; this exact procedure has not been tried end to end, so not verified.

**Change a rule.** Edit `data/manual/criteria.csv` (weight, filter, or a new row). Put thresholds in `R/00_config.R`. Rebuild: `10_run_ranking.R`, `11_build_payload.R`, tests, `check_facts.R`. Update `data/manual/facts.csv` if a published number moves.

**Add a data source.** Copy the pattern of `R/02c_usaspending.R` or `R/02d_federal_register.R`: fetch with a cache, write one CSV to `data/processed/`, add it to `R/03_merge_opportunities.R`, keep missing values as missing (never 0), and add checks in `tests/`. SAM.gov postings are not loaded; the SAM Assistance Listings file is used for program spending only.

## Known limits

- Keyword matching misses grants that use different words than the plan, and it makes odd matches. The match is only as good as the plan wording. Backtest results are in the fact sheet; they are mixed, and a soonest-deadline sort beat the original program-level test.
- Region and focus come from the wording of the title and text only. A grant for another state may still get through.
- The "NC has won this before" track record undercounts. Only 31 recipient matches are confirmed.
- SAM.gov shows $0 for many formula programs that do spend money. The tool treats an all-zero listing as unknown, not zero.
- Missing dates and award amounts are common. The tool shows "not listed", never a made-up value.
- Pursue, Maybe and Skip marks and the cart live in each browser; there are no accounts. Each mark is also sent to the app's `/feedback` log (agency, grant, rank, mark, a random browser code; no personal data) so `app/pilot_scorecard.sh` can report the pilot measure. Marks do not yet change the ranking.
- Four agency plans are old, and plan quality varies across agencies.
- Only 2 agencies (DHHS and DMVA) have a capability table.
- The daily refresh is a GitHub Actions run that re-scores cached data and redeploys the site; it does not fetch new postings from Grants.gov. Not yet verified on GitHub (the workflow has not run); do not describe it as live until it has.
- No evaluation with real agency staff has been done.
- API keys: `api_keys.env` is no longer tracked and is git-ignored (copy `api_keys.env.example`, add your own free Simpler.Grants.gov and SAM.gov keys). Only the data-collection scripts need keys. The ranking, tests and the Azure app need none.

## Where the numbers come from

Every number used in the tool text or slides is in [docs/fact_sheet.md](fact_sheet.md) with the script that makes it. `R/check_facts.R` re-derives them from [data/manual/facts.csv](../data/manual/facts.csv) and prints "49 of 49 rows pass". If a number is not in the fact sheet, do not trust it.

## More

Field notes and the organizer brief are in [archive/](../archive/). AI use: [AI_USAGE_LOG.md](../AI_USAGE_LOG.md).

GitHub Pages work: see `docs/expansion_plan_github.md` (plan) and `docs/real_app_criteria.md` (finish line).

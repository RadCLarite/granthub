# Handover: for a state developer picking this up

Rubric target: Solve, level 4 ("a README a state developer could pick up"). This page is the short path; `README.md` has the detail.

## First hour
1. Read `README.md` ("What it does", "Quick start", "How it works").
2. From `src/`, run `Rscript R/check_facts.R`. It must print "49 of 49 rows pass". Run `Rscript tests/run_tests.R` from `src/` (89 of 89 pass at the last full run). Caches are committed, so no API key and no model is needed.
3. Open the tool locally with the command in README "Quick start".

## What you own after handover
| Thing | Where | Change it by |
|---|---|---|
| Which agencies and what they care about | `data/manual/agency_map.csv`, `src/docs/agency_goal_summaries.csv` | README "How to extend", "Add an agency" |
| Scoring and filter rules | `data/manual/criteria.csv`; thresholds in `src/R/00_config.R` | README "Change a rule"; rebuild, test, `check_facts.R` |
| Tier rules (who must sign) | `src/tool/tiering.js` only | never copy them elsewhere |
| New data source | `src/R/02*` pattern, then `03_merge_opportunities.R` | README "Add a data source"; missing stays missing, never 0 |
| Every number shown | `data/manual/facts.csv`, `src/docs/fact_sheet.md` | a number not in the fact sheet does not ship |

## Running it in the cloud
- Resource names and every deploy so far: `src/docs/azure_setup.md`. Deploy steps: `app/deploy_azure.sh` (dry run by default; asks before each step).
- The app needs no key. Only the data-collection scripts do: copy `api_keys.env.example` to `api_keys.env` and add your own keys. Never commit the file; hold keys in Azure as secrets.
- The daily job (`app/job.R`) validates and stamps the payload. Real re-scoring needs the job image (`app/Dockerfile.job`) and write access to Blob; today it runs as a dry run. Fetching new postings is manual.

## Known sharp edges
- The cold start with zero replicas is about 38 seconds; keep one replica for anything people will use.
- `PAYLOAD_AS_OF` in `src/R/00_config.R` is fixed so reruns are identical; a real daily run must set it from the run date.
- Marks and the cart live in each browser; the `/feedback` log has no accounts.
- Step 4 of the pipeline uses macOS OCR for image-only plan pages; another OS needs a different OCR tool.
- The notice-reader model has a retirement date; check it before the pilot (see `docs/PILOT_PLAN.md`).

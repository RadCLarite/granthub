# Level 4 Solve: gap list and run plan (Sun Nov 8, 2026)

Source: the judging rubric photo. Level 3 = live demo end to end on Azure (ingest, score, rank, surface in a usable interface). Level 4 = Level 3 plus stretch goals, graceful handling of messy data, and a README a state developer could pick up.

Status below is read from `src/docs/azure_setup.md`, `src/docs/daily_job.md`, `app/job.R`, `app/Dockerfile.job` and the README. Nothing here was checked against live Azure from this session [uncertain until someone with `az login` re-reads it].

## Level 3 check (live demo end to end)
| Step | State | Evidence |
|---|---|---|
| Surface in a usable interface | Done | `ffm-app` v36 live, `/`, `/payload.json`, `/feedback` |
| Score and rank | Done, but baked into the image | scored on a laptop, payload copied into the image |
| Ingest on Azure | NOT done | fetch (`02a` to `03_merge_opportunities.R`) runs by hand |
| Daily job | Runs as dry run only | `ffm-daily-refresh` execution ffm-daily-refresh-7uhvu26 succeeded in 32 s but logged "no src/R under /srv/finalists; scoring skipped, shipping the baked payload" |

Honest line for the pitch if nothing below is done: the daily job proves the schedule and the payload check, it does not yet refresh data. Say that, do not claim a cloud refresh.

## Gaps, ordered by value for Level 4
1. **Job image scores for real.** `Dockerfile.job` is written but never built. Running job is on the app image (v36), which has no `src/R`. Build `ffm-job` from the repo root, point the job at it, run once, confirm the log says "scoring from cache" and `payload.json` md5 matches the repo copy.
2. **Job can write to Blob.** Marco's login cannot assign roles. Either an Owner grants `Storage Blob Data Contributor` on `ffmdatateam15` to the job identity, or a write SAS goes in as a Container App Job secret (`BLOB_WRITE_SAS`). Then set `JOB_DRY_RUN=0`. Until then the app serves the baked payload, which is fine for the demo.
3. **Ingest is automated or honestly labeled.** Not feasible to wire a fetch with new keys in the time left. Fallback that is true today: the label "data as of 2026-11-07 11:00" in the payload, plus the README statement that fetch is a manual, approved step. If time allows later: store the keys as Container App Job secrets (never in an image or file) and run `02a` to `03` before scoring.
4. **Stretch goals (rubric: "stretch goals").** Check which of the three bonus quests are live in the tool before the pitch: coverage/reach metric (fact sheet row 31 says done, exploratory), deadline alerts, feedback loop (`/feedback` live, pilot measure live). Say which are live and which are not. Do not name a bonus that is not in the deployed tool.
5. **Messy data.** Already handled: 488 open items with no close date and 887 with no award ceiling show "not listed", not a made-up value (README line 156). Add one sentence and one screenshot to the pitch.
6. **State-developer README.** Root README is a judge landing page with a requirement map. Missing for a developer: one block "to run this against a new state agency: edit these three tables in `data/manual/`" and the Azure resource list with names. Add it to `Finalists/README.md` after the key and history decisions are made.

## What is needed to run all of it (order, owner)
| # | Step | Owner | Needs |
|---|---|---|---|
| 1 | `az login` (Duo), confirm subscription | Marco | his phone |
| 2 | Read current state: `az containerapp show`, `az containerapp job show`, month-to-date cost in the portal | Marco or Kent | read only |
| 3 | Grant `AcrPull` on `ffmacrteam15` to the job identity, and `Storage Blob Data Contributor` on `ffmdatateam15` | a subscription Owner (Kent or organizers) | role assignment |
| 4 | `az acr build -r ffmacrteam15 -t ffm-job:v1 -f Finalists/app/Dockerfile.job .` from repo root | Marco | per-command approval |
| 5 | `az containerapp job update` to the new image, then `az containerapp job start` once; read the log | Marco | per-command approval |
| 6 | Only if step 5 shows real scoring and md5 matches: set `JOB_DRY_RUN=0`, start once, confirm Blob timestamp changes and the live page still loads | Marco | per-command approval |
| 7 | Warm the app (min replicas 1 already set; cold start is 38 s at 0) and set back to 0 after the talk | Marco | after 12:30 |
| 8 | Log every Azure command and result in `src/docs/azure_setup.md` and `AI_USAGE_LOG.md` | whoever ran it | |

Rule from the project: no `az` create, role assignment, build or deploy runs without the user's per-command approval. Steps 3 to 6 are outside what this session ran.

## Decision for Kent
Steps 4 to 6 are the only way to move Solve from "dry run" to "real scheduled refresh". Rough cost: a few minutes of build, well under $1. Risk: a bad image replaces the job only, never the live app. If the Owner role grant (step 3) cannot happen before 9:00, skip 2 and 6 and present the honest line above.

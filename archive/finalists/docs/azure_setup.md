# Azure setup: handoff and plan for Sat Nov 7

Written Fri Nov 6, 2026, late evening, by Marco with Claude Code. No keys, tokens or connection strings are in this file. Where a secret is needed, the placeholder is `$AOAI_KEY` etc.

## Rules that still apply
- **$500 is a monthly budget alert, not a hard limit** (read from Azure Friday night; the subscription spending limit is off). Treat it as the ceiling anyway. Stay on the cheapest tiers; see "Cost guard".
- Ask before every `az ... create`, delete, role assignment or install. One command at a time. On an error: show the exact command and error, propose one fix, no blind retries.
- Never print or write a key. Read it into a shell variable from `az` and use it in the same command.
- Work only on the branch `marco_testing`. No commits to `main`. Commit only when Marco says so; push only to `origin/marco_testing`, then open a PR for Kent. Before each work block: `git fetch origin`, then `git merge --ff-only origin/main`.
- AI use for Friday is logged in `Finalists/AI_USAGE_LOG.md`; add a row for each new block of work.

## State at end of Friday
_Updated Fri 10:50 pm: rows below show the state after the proof run. Details are in the proof sections further down._

Signed in as `gullotto@AD.UNC.EDU` (CLI 2.92.0, installed with Homebrew; `containerapp` extension installed, preview). Default subscription: `unc-sdis-solveathon-team15`.

| What | Name | State |
|---|---|---|
| Region | East US (`eastus`) | chosen; both models available there as Standard SKU (`gpt-4o-mini` 2024-07-18, `text-embedding-3-small` v1) |
| Resource group | `rg-primary-unc-sdis-solveathon-team15` | existed already; we reuse it |
| Resource providers | App, OperationalInsights, ContainerRegistry, CognitiveServices, Storage | registered Friday |
| Storage account | `ffmdatateam15` (StorageV2, LRS, no public blob access, TLS 1.2) | created |
| Blob container | `ffm-data` (created with `--auth-mode login`) | created |
| Log Analytics workspace | `ffm-logs` | created |
| Container Registry | `ffmacrteam15` (Basic) | created |
| Container Apps environment | `ffm-env` | created |
| Proof app | `Finalists/app/` (image `ffm-app:v1`, display only) | **built and live**; replaced the hello skeleton |
| Azure OpenAI resource | `ffm-aoai-team15` (S0, East US) | **created Sat 12:50 am**; `gpt-4o-mini` (DataZoneStandard, capacity 10) and `text-embedding-3-small` (Standard, capacity 10); both test calls returned 200 |
| Container App | `ffm-app` | **created and live**: https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/ |
| Budget alerts | `ffm-guard` | **created**: $50, $100, $250, $400. Alerts only; they do not stop spending |

Tested Friday night: see "Browser check" below.

## Plan for Saturday (in order)

### 0. Start of session (5 min)
1. `git fetch origin`; confirm branch is `marco_testing`; `git merge --ff-only origin/main`.
2. `az account show` (expect `unc-sdis-solveathon-team15`). If the token expired, Marco runs `az login` and approves Duo himself.
3. Read `planning/07_discovery_findings.md` and the latest `handoff.md` for anything Kent decided overnight (which agency, R versus Python, whether Azure OpenAI is ours). If Kent chose Python or Streamlit, stop and redo step 5 with that stack.

### 1. Decide first (ask Kent or a mentor, 9:00 check-in)
- Is Azure OpenAI ours to create, or do the organizers provide an endpoint? (Starter Kit says skip its Step 3 if provided.)
- Does R Shiny on Container Apps hold, or do we switch to Python?
These two answers decide steps 2 and 5. Do not guess.

### 2. Azure OpenAI (ask before creating)
- Check the `Microsoft.CognitiveServices` provider is `Registered`.
- Create `ffm-aoai-team15` (kind `OpenAI`, SKU `S0`, East US), then two deployments: `text-embedding-3-small` and `gpt-4o-mini`, Standard SKU, **small capacity** (for example 10 to 30 on the chat model) to cap cost.
- If creation is refused (quota, policy, access needing approval): record the exact error in this file, tell Kent, and fall back to keyword/TF-IDF scoring as the Starter Kit allows. Do not spend time fighting it.
- Check Azure's data-handling documentation before anyone claims "prompts are not used for training". Mark it [uncertain] until read.

### 3. Test the two calls (no key in output)
- Read endpoint and key into shell variables from `az cognitiveservices account ...`; run one embedding call and one chat call with `curl`; print only the HTTP status and token counts.
- Done when both return 200.

### 4. Build the image in the cloud
- `az acr build -r ffmacrteam15 -t ffm-app:v1 ./app` (no local Docker needed).
- If the build is slow or fails, record the exact error and tell Kent at once; this is the signal that R on Container Apps may be a problem.

### 5. Deploy the Container App
- Create `ffm-app` in `ffm-env`: external ingress, target port 3838, env var `MODE=app`, **min replicas 0 or 1 and max 1**, smallest CPU/memory (0.5 vCPU, 1 Gi). Pull from the registry using a managed identity or `--registry-identity`, not an admin password in a file.
- `curl -I https://<fqdn>` returns 200 and the page shows "MODE = app". Test once on the phone hotspot too (the demo must work on venue Wi-Fi and a hotspot).
- Note: a scale-to-zero app has a cold start of some seconds. Before the demo, set min replicas to 1 or warm it up.

### 6. Storage access for the app (only if time)
- Give the app a managed identity with `Storage Blob Data Contributor` on `ffmdatateam15` (role assignment: ask first). Agree the blob layout with Everett and Kent: `profiles/{agency}.json`, `raw/{yyyy-mm-dd}/grants.json`, `opportunities/latest.json`, `scored/{agency}/latest.json`, `decisions/{agency}.json`, `eval/labels.json`, `runs/{timestamp}.json`.

### 7. Cost guard
- Ask Marco about budget alerts at $250 and $400 (Cost Management budget). If his account cannot create one, note it here and check Cost analysis by hand at lunch and at 6:00 pm.
- Keep LLM calls to the top N results only (Starter Kit pitfall: calling the LLM for every item).
- Biggest runaway risks: a loop calling the model, an app with min replicas above 1, a large Log Analytics ingestion. Before leaving for the night, check cost and scale.

### 8. Close out
- Write the results into this file: the real URL, region, resource names, exact `az` commands (secrets as `$AOAI_KEY`), test results, failures and fixes.
- Add new rows to `AI_USAGE_LOG.md` (Friday's row exists): Claude Code (Sonnet 5.5) used for Azure CLI setup and file writing; human checks: Marco signed in and approved each create, read the resource list in the portal.
- Optionally update the Azure row in `handoff.md` (ask Kent first; it is his file).
- Post to the team: public URL, region, resource names, anything that failed. Commit on `marco_testing` only when Marco says so, then PR for Kent.

## Things I could not verify
- The `$500` limit comes from Marco's report; the cost figures in chat (ACR Basic about $5/month, scale-to-zero free when idle) are estimates, not read from Azure pricing.
- Whether Marco's account can create budgets and role assignments.
- Whether the `rocker/shiny:4.4.2` tag builds cleanly in ACR (not yet tried).
- Plan years, text extractability and which agency we serve are open on the data side; they do not block Azure.

## Rollback if anything goes wrong
Delete only resources we created (all names above, in `rg-primary-unc-sdis-solveathon-team15`). Do not delete the resource group, `rg-networking`, `NetworkWatcherRG` or `rg-serviceHealthAlert`. Ask Marco before each delete.

---

# Proof run result (Fri Nov 6 night, Claude Code, Sonnet subagent)

**URL:** https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/  (tool: `/tool.html`)
Image `ffmacrteam15.azurecr.io/ffm-app:v1`. Only 1 of 5 allowed builds used. No keys, passwords or tokens were printed or written.

## Resources created
- Subscription budget `ffm-guard` ($500 monthly, actual-cost alerts at 10/20/50/80% = $50/$100/$250/$400, contactRoles Owner and Contributor, no emails; start 2026-11-01, end 2027-11-01).
- Image `ffm-app:v1` in `ffmacrteam15`.
- Container App `ffm-app` in `ffm-env`: external ingress, port 3838, `MODE=app`, 0.5 vCPU, 1.0Gi, min 0, max 1, system-assigned identity. The CLI granted that identity `AcrPull` on `ffmacrteam15` itself (confirmed in the role assignment list). The admin-user fallback was NOT needed or enabled.

## Budget facts read first
- Month-to-date actual cost at start: $6.67 (same as the Friday baseline).
- Existing budgets: `unc-sdis-solveathon-team15-monthly-budget` is $500, Monthly, 2026-10-01 to 2036-10-01, one alert at 100% (emails to the organizers). There is also `unc-sdis-solveathon-team15-annual-budget`, $6,000, Annually, 2026-10-01 to 2027-12-01. So the $500 is a monthly budget alert, not a hard limit.

## Commands (secrets: none needed)
```
az rest --method PUT --url ".../subscriptions/<sub>/providers/Microsoft.Consumption/budgets/ffm-guard?api-version=2023-05-01" --body @budget.json
sh Finalists/app/stage_proof_assets.sh
az acr build -r ffmacrteam15 -t ffm-app:v1 ./app --no-logs      # run from Finalists/
az containerapp create -n ffm-app -g rg-primary-unc-sdis-solveathon-team15 --environment ffm-env \
  --image ffmacrteam15.azurecr.io/ffm-app:v1 --ingress external --target-port 3838 --env-vars MODE=app \
  --cpu 0.5 --memory 1.0Gi --min-replicas 0 --max-replicas 1 --system-assigned \
  --registry-server ffmacrteam15.azurecr.io --registry-identity system
```

## Test results
| Check | Result |
|---|---|
| `/` returns 200 | PASS |
| `/tool.html` returns 200 (3,594,932 bytes, same size as the staged file) | PASS |
| `/` shows `MODE = app` | PASS |
| Counts in plain curl HTML: total 6,523; posted 884; forecasted 588; closed 4,947; notice 104 | PASS (static UI) |
| Cold start (after replicas reached 0, about 9 minutes of no traffic) | 38.2 s for `/` |
| Warm request | 0.09 to 0.15 s for `/` |
| No key in app/ context or in changed/untracked files (value match against `api_keys.env`, nothing printed) | PASS |
| Browser, websocket, table filtering | NOT tested (Marco does this) |
| `MODE=job` in the cloud | NOT tested (needs a Container Apps job, not approved) |

Notes: scale to zero took about 9 minutes after the last request. The cold start of 38 s is a finding: the sponsors said waiting minutes fails, so set min replicas to 1 before any demo. One earlier curl, run right after creation with no timeout, hung for over 3 minutes and was stopped; later requests worked at once. Cause not determined (possibly first-ingress propagation). Also `fread` warned that `bit64` is not installed (integer64 columns); harmless for display.

## Failures and fixes
None in the build or deploy. `.dockerignore` was written so the staged `data/` and `www/` are not excluded; they reached the image (row counts and tool file are live). ACR dropped only `.gitignore` from the context.

## Spend ledger (estimates, list prices)
| Item | Duration | Estimate |
|---|---|---|
| Build v1 | 462 s wall clock (includes queue time) | 462 x 2 vCPU x $0.0001 = about $0.09 |
| App active (about 30 minutes incl. cold start and tests) | about 0.5 h | about $0.03 |
| Total added | | about $0.12; Azure's own figure lags, not re-read |
App at min replicas 0 costs near zero idle, about $0.054 per hour while active.

### Browser check (Fri Nov 6, 10:40 pm, main session)
Independent of the subagent's curl checks, in a real browser:
- Shiny websocket connected (`readyState` 1), no disconnect overlay, no console errors.
- Table search works server-side: "school bus" gave 690 of 6,523 rows, and clearing it restored all rows.
- `/tool.html` loads and shows Tier 1 to 4 as 27 / 24 / 3 / 366 (runs in the browser, so this does not test V8 on the server).
- Azure settings re-read: image `ffm-app:v1`, 0.5 vCPU, 1 Gi, min 0, max 1, system identity pull, registry admin off, no secrets on the app.

Finding: the "school bus" results are noisy. The search matches each word separately across all columns, and the top rows are unrelated to buses. Do not use this search as evidence of matching quality. It may be a useful picture of what plain keyword search does, once measured.

Still untested: `MODE=job` in the cloud, venue Wi-Fi and phone hotspot, V8 on the server. The cause of one early hung `curl` right after creation is unknown.

### Azure OpenAI (Sat Nov 7, about 12:50 am, Marco asked for it now, replacing the wait for the 9:00 check)
Nobody has yet confirmed it is ours to create, so confirm at the 9:00 check-in. If the answer is no, delete `ffm-aoai-team15` (ask Marco first).

```bash
az cognitiveservices account create -n ffm-aoai-team15 -g rg-primary-unc-sdis-solveathon-team15 -l eastus --kind OpenAI --sku S0 --custom-domain ffm-aoai-team15 --yes
az cognitiveservices account deployment create -n ffm-aoai-team15 -g rg-primary-unc-sdis-solveathon-team15 --deployment-name text-embedding-3-small --model-name text-embedding-3-small --model-version 1 --model-format OpenAI --sku-name Standard --sku-capacity 10
az cognitiveservices account deployment create -n ffm-aoai-team15 -g rg-primary-unc-sdis-solveathon-team15 --deployment-name gpt-4o-mini --model-name gpt-4o-mini --model-version 2024-07-18 --model-format OpenAI --sku-name DataZoneStandard --sku-capacity 10
```

- Endpoint: `https://ffm-aoai-team15.openai.azure.com/`. API version tested: `2024-10-21`. Key: `$AOAI_KEY`, read from `az cognitiveservices account keys list` into a shell variable. Never write it to a file.
- Failure and fix: `gpt-4o-mini` on `Standard` was refused (`ServiceModelDeprecated`, deprecated since 03/31/2026). `DataZoneStandard` worked; it processes within the US data zone [per Azure SKU naming; read the docs before claiming this].
- Model retirement dates listed by Azure: `gpt-4o-mini` 2027-04-14, `text-embedding-3-small` 2028-02-09.
- Tests: chat 200 (15 tokens), embeddings 200 (4 tokens, 1,536 dimensions).
- Cost so far: under one cent for these tests. No fixed monthly charge is expected for pay-per-token deployments [from list pricing, not confirmed on the bill].
- Not done: wired into the app or pipeline; no call cap in code yet; data-handling terms not read, so privacy stays [uncertain].

## Saturday Nov 7: Blob wiring and tool deploy (Marco with Claude Code)
No keys, tokens or SAS values are in this file.

| What | State |
|---|---|
| Image | `ffm-app:v2` live (revision `ffm-app--0000002`), built with `az acr build` (about 1.5 min on Basic) |
| Main page | `/` serves `src/tool/matchmaker.html` (agency picker, top 10). Old Shiny view at `/shiny`; qualifier tool at `/tool.html` |
| `/payload.json` | Route in `app/app.R`. Fetches `ffm-data/payload.json` server-side, caches 60 s, `no-store` to the browser |
| Auth to Blob | Read-only SAS on that one blob, expires 3 days from Sat Nov 7, stored as Container App secret `blob-sas`, passed as env `BLOB_SAS`. Managed identity code path exists as fallback |
| Why a SAS | Marco's login cannot assign roles (`roleAssignments/write` refused: ABAC condition). Storage Blob Data Reader for the app identity and Contributor for Marco are still needed, from Kent or a subscription Owner |
| Uploads | `payload.json` uploaded with account-key auth through the `az` login (key never printed or written). First a fake stub, then Kent's Merge 1 stub |
| Scale | min 0, max 1 (unchanged). Cold start about 35 s; the first request after the deploy returned 404 once, then 200 |

To replace the SAS with managed identity once roles exist: assign Reader to the app identity, remove env `BLOB_SAS`, delete secret `blob-sas`. The app then takes the managed-identity path.

### Spend added Sat Nov 7 (estimates, list prices; Azure's own figure lags and was not re-read)
| Item | Estimate |
|---|---|
| Build v2 | 1 min 23 s x 2 vCPU x $0.0001 = about $0.02 |
| Storage and Blob reads | not itemized; far under $1 |
| Model calls | none made today |
| Total added today | well under $1; nowhere near the $50 stop line |

### Not yet done
- Real `payload.json` after Merge 2 (the Blob file is still Kent's stub).
- Min replicas: set to 1 on Sat Nov 7 at about 9:55 am with Marco's OK (about $0.054 per hour active at list price, about $1.30 per day; ask T3 whether there is a cheaper warm-up). Set back to 0 after Sunday's talk.
- Daily Container Apps Job: `app/job.R` written (checks the payload shape, stamps `shipped_at`, uploads to Blob; dry run by default, tested locally on three inputs). Not yet built into an image or created as an Azure job. Writing to Blob needs a write SAS (`BLOB_WRITE_SAS`) or the Contributor role for the app identity, neither of which exists yet. Creating the job resource needs Marco's OK.
- Phone check and warm-load timing.

## Sat Nov 7 deploy run (Marco's Claude, 11:40 am)
- Done: `ffm-app:v3` built in `ffmacrteam15` (run ca6, succeeded). `ffm-app` updated to revision `ffm-app--0000007`. Live URL answers 200: `/` (0.09 s warm), `/payload.json`, `/tool.html`.
- Not done, step 4 (upload new `payload.json` to Blob): refused, Marco's login lacks a Storage Blob Data write role, and role assignment is refused. The Blob still holds the older payload (960 rows, 32 agencies, no `goals[]`), so the new tool's match board has no plan goals live.
- Not done, step 6 (daily job): `az containerapp job create` failed, the job's system identity cannot pull from the registry (no AcrPull). Needs an Owner to grant `AcrPull` on `ffmacrteam15` to the job identity, or a job created with the registry admin credentials (not enabled).
- Step 7 not run (no job). Spend added today: not measured (an image build is about $0.02 by the script's estimate; unverified).
- Needs from a subscription Owner (Kent or organizers): `Storage Blob Data Contributor` for Marco on `ffmdatateam15`, `AcrPull` for the job identity.

## Sat Nov 7, ~5:30 pm: deploy readiness check (Kent's Claude, covering Marco's lane)
Read-only from a laptop without the `az` CLI, so no Azure query was possible and **actual spend was not read** (slide plan task 3 stays open: read it in the portal, Cost Management, month to date).
- Live now (checked by `curl`): `/` serves the **older** matchmaker (no swipe mode); `/payload.json` is the 11:00 payload without the new row fields (`funder` etc.). Nothing from PR 102 or later is live.
- `app/deploy_azure.sh`: default tag moved v3 -> **v4** (v3 is live; rebuilding a live tag may not roll a new revision). Step 4 (Blob upload) is marked optional: it was refused at 11:40, and skipping it is safe because `app.R` prefers the baked payload when its `data_as_of` is the same or newer than Blob's (both 2026-11-07T11:00). New step 5b checks the live page for "Start swiping".
- Fix for step 6 (job create, no AcrPull) [unverified which route our roles allow]: (a) a subscription Owner grants `AcrPull` on `ffmacrteam15` to the job's identity, or (b) enable the registry admin user and create the job with `--registry-username/--registry-password`. Either way the job on the **app** image only re-ships the baked payload; real daily scoring needs the `Dockerfile.job` image (`ffm-job:v1`).
- Fix for Blob writes: `Storage Blob Data Contributor` on `ffmdatateam15` for the deployer (Owner must grant), or a write SAS passed as `BLOB_WRITE_SAS`. Not needed for the demo.
- Judge snapshot (`app/make_snapshot.sh`): now also excludes `archive/stale`, `stale/`, `graphify-out/`. Built and checked: no key file or key value, no `.git`, `.RData`, `.Renviron`; 23,419 files, 461 MB (193 MB zip; `data/` is most of it, no file over 25 MB). On that snapshot with no keys: `10_run_ranking.R`, then 84 of 84 tests and 49 of 49 fact rows, and `11_build_payload.R` rebuilt `payload.json` byte-identical.
- Exact order for tonight and Sunday: `saturday/deploy_checklist_sun.md`.

## Deploy Sat Nov 7, ~6:05 pm ET (Marco's machine, Marco's Claude)
- Built `ffm-app:v20` with `az acr build` (az 2.92.0, containerapp 1.3.0b5) from `main` at `39048df` (PR 111 merged). Run status: Succeeded.
- `az containerapp update --image ffmacrteam15.azurecr.io/ffm-app:v20` → revision `ffm-app--0000025`, provisioning Succeeded. Min replicas already 1 (left as is).
- Blob upload skipped (no write role); the baked payload in the image is served. Live `/payload.json` is byte-for-byte equal to the repo's `data/processed/payload.json` (960 rows, data_as_of 2026-11-07 11:00).
- Check: live `/` contains "Start swiping" (new tool). The 7 "U.S. Embassy The Hague" rows are eligibility "no" (hidden examples only), not matches.
- Not done: daily job (still dry run), spend not read.
- Sat ~6:20 pm: quick declutter deployed as `ffm-app:v21` (home quick-picks, evidence card, at-a-glance and money-vs-time charts, estimate chips and per-card feedback row hidden; pop-up off; white page). Live page checked.
- Sat evening: simplified tool (commit a4d88eb) deployed as `ffm-app:v22`, revision ffm-app--0000027, after Marco checked it locally. Live page checked (new agency picker present).
- Sat night: v23 deployed (revision ffm-app--0000028): adjustable impact weights, Match board, single arrows, feedback form sent to GET /feedback (logged as FEEDBACK lines; read with app/read_feedback.sh). Live page and /feedback checked.
- Sat night: v24 deployed (revision ffm-app--0000029): Shipley color-team timeline and How this works section. Live page checked.
- Sat night (about 11:00 pm): v32 deployed (revision ffm-app--0000037) from `main` at a4deb63 (PR 117): situation-box Apply fix (second `SYN` table renamed `SYN_G`) and Start over clears saved grants. v25 to v31 were deployed by teammates without a log line here. Built with `az acr build` (run ca18, Succeeded); min replicas left at 1. Live page checked: byte-identical to `src/tool/matchmaker.html` on `main`, and `?demo=1` then Apply shows 3 grants with DERA first.
- Sat night (about 11:10 pm ET, 04:09 UTC): v33 deployed (revision ffm-app--0000038) from `main` at 9146e46 (PR 118): Display menu readable in both color modes, opens on screen, sits above the tab bar; urgent stub contrast. Live page checked byte-identical to `main`.
- Sat night (about 11:30 pm ET, 04:30 UTC): v34 deployed (revision ffm-app--0000039) from `main` at ab38a99 (PR 119): grantHub name and logo, Recent decisions fix, Email my list removed, Back to choose your agency, Simple/Detailed switch on desktop. Live page checked.
- Sat night (about 11:50 pm ET, 04:47 UTC): v35 deployed (revision ffm-app--0000040) from `main` at 7950b4f (PR 120): "Who it reaches" (population tags with quotes; qualifier ACS county and district geography in the payload). Live page and live /payload.json checked (11 groups, 313 tagged rows).
- Sun Nov 8 (about 12:00 am ET, 05:00 UTC): v36 deployed (revision ffm-app--0000041) from `main` at 790b88a (PR 121): marks sent to /feedback for the pilot measure; Pilot measure line in My grants. Live page checked. A `type:"test"` record sent to /feedback returned 200 and appeared in `sh app/read_feedback.sh`; `sh app/pilot_scorecard.sh` on the live log: "No Top 10 marks in this log yet" (no real user marks).
- Sun Nov 8, 05:02 UTC: daily job `ffm-daily-refresh` updated from image v4 to v36 and started once by hand (execution ffm-daily-refresh-7uhvu26): **Succeeded** in 32 s. Its log: "no src/R under /srv/finalists; scoring skipped, shipping the baked payload"; "dropped 15 rows whose close date is before 2026-11-08"; "payload ok: 32 agencies, 945 rows"; "JOB_DRY_RUN is on: nothing written to Blob". So the refresh step runs on Azure, but with the app image it only checks and trims the baked payload; re-scoring needs the job image (`Dockerfile.job`, not built) and writing needs a Blob write role. Schedule stays 11:00 UTC daily, dry run.

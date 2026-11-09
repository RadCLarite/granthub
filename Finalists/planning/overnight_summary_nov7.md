# Overnight summary, Sat Nov 7, 7:00 am (Claude for Marco)

## Status in one line
The app is live on Azure and all the proof tests passed. Spend is far under the cap. Kent accepted the tool plan (09) overnight, and PR #14 is merged into main. Nothing broke and no stop rule fired.

## The app
URL: https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/ (Shiny at `/`, qualifier JS tool at `/tool.html`). Checked at 7:00: running, image `ffm-app:v1`, min 0, max 1 replicas.

| Test | Result |
|---|---|
| `/` and `/tool.html` return 200 over HTTPS | Pass |
| Page shows `MODE = app` and 6,523 rows (884 posted, 588 forecasted, 4,947 closed, 104 notice) | Pass |
| Websocket connects, table filters in a real browser, no console errors | Pass |
| JS tool loads on Azure | Pass (shows qualifier data, not Finals data) |
| No key in the build files, image or commits | Pass |
| Warm load | About 0.1 to 0.16 s |
| Cold start | **38 s** after scaling to zero (set min 1 before demos) |
| Never tested | `MODE=job` in the cloud, phone hotspot, Blob, Azure OpenAI wired into the app |

## Spend
| | Amount |
|---|---|
| Month to date at start (Fri 9:50 pm) | $6.67 |
| Month to date now (read 7:00 am) | $7.08 |
| Added overnight, actual so far | **$0.41** |
| My estimate of the true total | Under $5 (cost data lags by hours, up to a day) |
| Tonight's cap | $100. Not reached. The $25 stop and $75 kill switch did not fire |
| Builds used | 1 of 5 |

These are list-price estimates, and Azure posts costs late. Azure won't stop spending by itself (spending limit is off, budgets only send alerts). Today's stop from the team plan: **tell Kent at $50 added today.**

## What changed on Azure
- Built `ffm-app:v1` in `ffmacrteam15`. Created `ffm-app` in `ffm-env` (0.5 vCPU, 1 Gi, managed identity with AcrPull, registry admin off).
- Created budget `ffm-guard` with alerts at $50, $100, $250 and $400. They go to Owner/Contributor email, not to this session.
- Created Azure OpenAI `ffm-aoai-team15` (East US): `gpt-4o-mini` (DataZoneStandard, because Standard was refused as deprecated) and `text-embedding-3-small`. Both calls tested. **Not wired in, and no call cap yet.**
- Nothing was deleted. No other resources were created.

## What changed in git
Pushed from `marco_testing`, then merged to main via PR #14 (`6b007d0`):
- `56dcb41` tool plan proposals (`planning/09_tool_plan_update.md`)
- `ba41d6f` handoff Azure row and overnight handoff note
- `5bc5e36` Azure OpenAI setup and test results (`src/docs/azure_setup.md`)
- Earlier: the proof app in `Finalists/app/` and `08_saturday_plan.md` (already on main)
- This summary is pushed to `marco_testing` too. It is not on main.

## What the team decided overnight (`Finalists/saturday/`, PRs #15 and #16)
- **09 proposals 1 to 8 are now the source of truth.** Award history is the main evidence, and DERA replaces Clean School Bus as the named case.
- 1:00 gate: an Azure URL with an agency picker and keyword top 10, plus the award backtest for DPI, DEQ and DHHS. Pass bar: 50% of won programs in the top 10, in 4-week windows, for 2 of 3 agencies.
- Notice reader is **advisory only** (a label plus a checked quote, never hides anything). It moves ahead of chat reasons in the cut order, and Noah spot-checks 30. Your lane owns `30_notice_reader.R`.
- Picker shows 32 agencies: State Board of Education folds into DPI, and Guiding Principles is dropped.
- Merge windows are 9:30, 11:00, 12:15 and 5:30. Kickoff is 8:30, and building stops at 6:00.
- At 7:00 pm you build the clean snapshot repo for judges: no `.git`, no `api_keys.env`.
- Your brief is `Finalists/saturday/people/marco.md`. It uses branches named `marco/sat-<topic>`.

## Open or untested
- **Azure OpenAI ownership is unconfirmed.** Matthew asks the organizers by 9:30.
- No model call cap exists in config yet. Add one before the notice reader runs.
- The model labels from PR #12 were reverted on main. Kent answers where the output went at kickoff.
- The diagram right edges and `drafts/claude/diagrams/report.html` were never checked visually.
- `09_tool_plan_update.md` still says `model_label.R` is not in the repo. It was briefly (`02109fd`) and then reverted.

## Before 9:00
1. Open the URL on your phone. Expect up to 38 s for the first load.
2. Run `az login` (with Duo) if the login has expired.
3. Read `saturday/people/marco.md` and `saturday/03_contract.md`.
4. Check that Matthew is asking about Azure OpenAI. Until he gets an answer, don't call it from the app.
5. Decide whether min replicas stay at 0 until the 11:00 mentor demo. My suggestion: set 1 at about 10:45.

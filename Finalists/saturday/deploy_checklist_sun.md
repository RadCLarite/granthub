# Deploy checklist: Sat night and Sun Nov 8

Written Sat Nov 7, ~5:30 pm, by Kent's Claude (covering Marco's lane). Needs someone with the Azure login (`ONYEN@ad.unc.edu` + Duo) and the `az` CLI with the containerapp extension. The laptop this was written on has no `az`, so nothing below has been run tonight. Background and failures: `src/docs/azure_setup.md`.

## What is live now (one line per piece)
| Piece | State | How checked |
|---|---|---|
| App (`ffm-app`, image `ffm-app:v3`) | **Live, but the older tool.** No swipe, cart, compare or the embassy filter | `curl` of `/` and `/payload.json`, Sat ~5:30 pm |
| Payload in Blob (`ffmdatateam15/ffm-data/payload.json`) | Old 11:00 payload. Uploads refused (no write role) | `azure_setup.md`, 11:40 am |
| Daily job (`ffm-daily-refresh`) | **Not live.** Create failed (no AcrPull). Scheduled refresh is not verified, so do not claim it on a slide | `azure_setup.md`, 11:40 am |
| Azure OpenAI (`ffm-aoai-team15`, `gpt-4o-mini` DataZoneStandard) | Created and test-called Sat 12:50 am. **Not used by the tool** (no model in the ranking or page) | `azure_setup.md` |
| Spend | Not read tonight (no `az` here). Last recorded: $6.67 month to date at start, "well under $1" added Sat (estimates) | Read in the portal before the slide uses it |

## Tonight, once the final branch is merged to `main` (UI fixes and docs PRs into `kent/sat-wrapup`, then that into `main`)
Run from `Finalists/` on an up-to-date `main`:
1. `git pull` and confirm `Rscript src/R/check_facts.R` from `src/` passes (after `Rscript R/10_run_ranking.R`).
2. `sh app/deploy_azure.sh` dry run: read the plan. It should say `ffm-app:v4`.
3. `az login` (Duo), then `az account show` to confirm subscription `unc-sdis-solveathon-team15`.
4. `DEPLOY=yes sh app/deploy_azure.sh`. Answer:
   - step 1 **y** (stage assets; must print "staged OK; secret check passed")
   - step 2 **y** (payload check)
   - step 3 **y** (image build, about 1.5 min, about $0.02 [estimate])
   - step 4 **N** (Blob upload; refused before, not needed)
   - step 5 **y** (point the app at v4)
   - step 5b **y** (prints a number of 1 or more if the new page is live)
   - steps 6 and 7 **N**, unless an Owner has granted AcrPull (see `azure_setup.md`)
5. Open the URL on a phone and a laptop: `?agency=dpi`, type "clean diesel school buses, I have 4 weeks", DERA first; then `?agency=deq`. Check there are no U.S. Embassy grants in the Treasurer (`?agency=dst`) list.
6. Write the new revision name and time in `src/docs/azure_setup.md`.

## Sunday morning
| When | Step | Command |
|---|---|---|
| before 8:30 | Keep one replica warm (no ~38 s cold start). About $0.054/h at list price [estimate] | `az containerapp update -n ffm-app -g rg-primary-unc-sdis-solveathon-team15 --min-replicas 1` |
| right after | Load the page once and confirm it is the new tool | `curl -s https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/ \| grep -c 'Start swiping'` (1 or more) |
| before 8:30 | Product link for the form: the URL above | |
| 10:26 to 10:34 | Talk. Backup: the recorded 90-second demo (slide plan task 13) in case of Wi-Fi trouble | |
| after the talk | Back to zero | `az containerapp update -n ffm-app -g rg-primary-unc-sdis-solveathon-team15 --min-replicas 0` |

## Judge snapshot (if the form wants a repo without keys)
From anywhere in the repo on final `main`: `Finalists/app/make_snapshot.sh <out_dir>` writes the folder and a zip (about 193 MB). It refuses to finish if any key value, key file, `.git`, `.RData` or `.Renviron` is inside. Note: `Finalists/api_keys.env` is tracked in git with real keys, so the GitHub repo itself must stay private, or the keys must be rotated before it is shared.

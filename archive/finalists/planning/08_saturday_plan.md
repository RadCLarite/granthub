# Saturday plan: Nov 7, 2026 (for Marco to confirm)

> **Saturday Nov 7 update:** `../saturday/` (start at `../saturday/README.md`) overrides this file where they differ.

Rewritten Fri Nov 6, about 11:10 pm, by Claude for Marco, after Kent's [15 product decisions](https://github.com/KApolloL/SolveAThon_2026/blob/main/Finalists/planning/08_product_decisions.md) landed on main. **Those decisions are the source of truth.** This is a draft, and nothing here runs until Marco confirms it.

**Update Sat 12:30 am:** the tool proposals in [09_tool_plan_update.md](09_tool_plan_update.md) and amendments A to L supersede this file where they differ. Main is already merged.

Related: [azure_setup.md](../src/docs/azure_setup.md) | [framing worksheet](02_framing_worksheet.md) | [discovery findings](07_discovery_findings.md)

## Where we start
**Azure hosting works.** `ffm-app` is live at https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/

Kent's decision 6 makes the product the **qualifier's JS tool reading `payload.json`**, with Azure OpenAI and Blob, and the R Shiny page is the **fallback**. Tonight's proof still helps: the JS tool already runs on Azure at `/tool.html`, though it shows qualifier data, not Finals data.

| Check | Result |
|---|---|
| `/` and `/tool.html` return 200 | Pass |
| Shiny page shows `MODE = app` and 6,523 rows (884 posted, 588 forecasted, 4,947 closed, 104 notice) | Pass |
| Websocket connects, table filters in a real browser, no console errors | Pass |
| JS tool loads on Azure and shows 27 / 24 / 3 / 366 | Pass |
| No key in the build files or commits | Pass |
| Warm page load | About 0.1 to 0.2 seconds |
| Cold start | **38 seconds** after the app scales to zero |
| `MODE=job` in the cloud, phone hotspot, Azure OpenAI, Blob | Not tested |

No matching, ranking or AI exists yet.

## Confirm before 9:00
1. **Your roles.** The runbook gives you Azure, plus Q&A and proof with Kent. This plan assumes that, not "Azure + app" from Friday. Check with Kent who builds the JS tool work.
2. **Today's spending stop.** Proposed: stop and talk at **$50 added today**. Expected use is under $20.
3. **Azure OpenAI.** Kent's plan lists it as your Azure step. It was left out tonight, so it is the first job. Still confirm at 9:00 that it is ours to create, unless Kent already knows.
4. **Bring main into `marco_testing`.** Kent asked for this. The branch has diverged, and the repo's rules stop Claude merging, so you or Kent must do it (commands below). No file overlaps at last check.

## Tell Kent first thing: these affect the 1:00 gate
1. **The gate cannot pass as written.** It requires Clean School Bus (CFDA 66.045) to appear for education and environment, but that CFDA has **0 rows** in `opportunities.csv`. Closest item: the 2026 DERA notice `EPA-OAR-OTAQ-26-01` (CFDA 66.039, posted, closes 2027-01-22), the only item mentioning school buses. Its applicant type is only "other", so a person must read its eligibility. Replace the gate item, or find the program another way.
2. **"N = 20 per pool" could make the recall test meaningless.** If top N is measured inside a 20-item pool, recall is automatically 100%. N must be the shortlist cap on the agency's full ranked list. The kit warns on this; Kent should state N.
3. **Does "maybe" count as relevant for the 70%?** Decide before labeling.
4. **Decision 8 may mislabel real deadlines.** Of the 70 far-future items, 23 close during 2030 and could be real dates. 43 are 2076 or 2099, clearly placeholders. The planned 10-item sample should include 2030 dates.
5. **Forecast dates go stale.** 197 forecasted items have close dates before Nov 6 (for example `RFA-HD-27-001`, Nov 2), so "days left" goes wrong for them. No decision covers this yet.
6. **"$500 spend cap" is not a cap.** Azure will not stop spending: the subscription limit is off, and the $500 budget only alerts the organizers. We hold spend down by limiting what runs.
7. **No human decision button is in the 15 decisions.** The Starter Kit's "never cut" list includes one, and the brief says people make the final call. Decision 10's feedback button only tunes weights, and it is first on the cut list. Add a simple Pursue / Maybe / Pass, or say why not.
8. **Evaluation choices** (full list in `drafts/claude/eval/README.md`): which recall counts (relevant only, or plus maybe; both labelers or either), whether closed items belong in the pool (kept out for now), and whether higher-education-only counts as ineligible.
9. **Check DHHS goals.** Decision 12 calls the text partly OCR, but `plan_text_extract_log.csv` shows 0 OCR pages for it.
10. **Other data gaps:** of 1,472 open items, 723 have no award ceiling, 60 list 0, 117 have no close date, and about 440 have HTML codes in their text.

## Ready for the team
- `drafts/claude/eval/`: blind label sheets for all 3 pool agencies (20 items, 2 labelers each), scoring and pool rules, matching decisions 12 and 15. 34 of 34 tests pass, on fake data only. Everett's lane. People do the labels, and the pool is not redrawn once scoring starts.
- `drafts/claude/docs/`: field notes and state-developer README drafts, with a `[TO FILL]` list.
- `drafts/claude/diagrams/`: architecture, security and stakeholder diagrams plus `report.html`, tagged LIVE or PLANNED. Open them in a real browser once; their right edges and `report.html` have not been checked visually. Severities, the RACI and stakeholder scores are drafts.

## Marco's day
| When | Do | Done means |
|---|---|---|
| 7:00 | Read the overnight summary | |
| Before 9:00 | Confirm this plan. Open the URL on your phone. `az login` with Duo if needed. Check Cost analysis. Merge main | URL loads; branch current |
| 9:00 | Give Kent the list above. Confirm Azure OpenAI | Gate item and N decided |
| 9:00 to 10:00 | Create `ffm-aoai-team15`, deploy `gpt-4o-mini` and `text-embedding-3-small`, test both calls. Read the Azure data-handling documentation | Both return 200; pipeline team has what they need, with keys kept out of files |
| 10:00 to 11:30 | **Blob, once Kent says yes** (his rule). Give `ffm-app` read access (a role assignment). Upload `payload.json` and cache | App reads Blob; new data needs no rebuild |
| 11:30 to 1:00 | Serve the JS tool as the main page, reading Finals `payload.json`. Keep Shiny at a side path as the fallback | Tool loads with Finals data on Azure |
| **1:00 gate** | Working ranking per agency, recall number, known-good case, deterministic rerun | If short, cut per decision 15: feedback button, LLM tier upgrade, presets |
| 1:00 to 4:00 | Support Azure reasons with the quote check. Mentor drop-in with a real failure. Start the Q&A cheat sheet | Reasons run within a call cap |
| 4:00 to 7:00 | Hostile-judge run. Check slide numbers against the fact sheet. Keep the AI log current. Hotspot test. Backup demo recording | Each slide number traced to a script |
| 6:00 | Cost and scale check | Spend written in `azure_setup.md` |
| 7:00 freeze | Finish `azure_setup.md`. Commit and open the PR for Kent | PR open |
| Sun before 10:00 | Set min replicas to 1 and load the page once | No 38-second wait in the demo |

**Cost:** Azure OpenAI looks cheap. Embedding all 6,523 rows and 158 goals is well under $1, and reasons for 680 shortlisted pairs about $0.50 [estimates from list prices, assuming 500 tokens per row and 3,000 in and 300 out per call]. The risk is a loop or an uncapped run, so set a call cap in `00_config.R` and rely on the cache. Keep one replica warm at about $0.05 per hour for rehearsals, then turn it off.

**Build speed:** the first image took 7.7 minutes, mostly compiling R packages. If Shiny stays in the image, switch to prebuilt packages and keep the data in a late layer.

## Merging main (you or Kent, not Claude)
```bash
git fetch origin
```
```bash
git switch marco_testing
```
```bash
git merge --ff-only origin/marco_testing
```
```bash
git merge origin/main
```
```bash
git push origin marco_testing
```
If `git switch` fails because another worktree holds the branch, run these in that worktree. Or open a PR from `marco_testing` to `main` and let Kent merge it.

## Suggested `handoff.md` Azure row (Kent's file, so not edited)
> Azure: `ffm-app` live at the URL above (Shiny fallback at `/`, qualifier JS tool at `/tool.html`, image `ffm-app:v1`, 0.5 vCPU, 1 Gi, min 0, max 1, managed identity pull). Budget alerts `ffm-guard` at $50, $100, $250, $400; alerts do not stop spending. Azure OpenAI not created. Details in `src/docs/azure_setup.md`.

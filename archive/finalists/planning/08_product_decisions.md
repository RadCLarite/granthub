# Product decisions (confirmed by Kent, Fri Nov 6 night, after a grilling interview)

> **Saturday Nov 7 update:** `../saturday/` (start at `../saturday/README.md`) overrides this file where they differ.

Source of truth for what we build. Anything here overrides the "chosen option" lines in `02_framing_worksheet.md` where they differ. Reasoning for each choice came from the interview; the qualifier design reused here is in `../../QualifierChallenge/` (`src/tool/tiering.js`, `src/tool/ui.js`, `src/R/00_config.R`).

## The 15 decisions
1. **Views.** One scored table of every opportunity against every agency. The agency picker (with multiselect) is the main screen. A second tab groups by opportunity and shows which agencies fit it. Build the status-filter table first, closed items scored too.
2. **Missed.** "Missed" means "the tool would have flagged this", with no claim about what the agency saw. "NC has won under this CFDA before" (USAspending) is a separate context column and never proof of a miss.
3. **Flag.** Score above a threshold, capped at N. Stale or thin profiles (Auditor, Elections, Wildlife Resources, Commerce) get a warning. The threshold is the lowest score that keeps 70% recall in the top N on the pool. Both settings live in `src/R/00_config.R`.
4. **Eligibility.** Clearly ineligible items are hidden by default, with a visible count and a toggle. Blank or unclear eligibility shows as "check eligibility". Applicant-type codes are verified against the Grants.gov list before we rely on them.
5. **Ordering.** The qualifier's impact score. Percentile-ranked parts, missing parts dropped with the remaining weights rescaled, slider weights 0 to 3, presets, sort by score or soonest deadline, per-item breakdown. Rules decide the flag. The score only orders.
6. **Stack.** The qualifier's JS tool reading `payload.json`. Azure OpenAI writes embeddings and reasons, Blob holds payload and cache, Container Apps hosts. Marco's R Shiny proof is the fallback.
7. **Fit.** Azure embeddings score every opportunity-agency pair once, cached. Azure chat writes a short reason with a plan quote and a notice quote only for flagged or shown pairs. A script checks that each quote appears in its source. Temperature 0 and the cache make reruns identical. The LLM never decides.
8. **Far-future dates.** The 70 posted items with close dates after 2030 read "rolling or no date listed". Deadline is unknown, weights rescale, and they sort last on soonest. Sample 10 against Grants.gov before the gate.
9. **Notices.** The 104 Federal Register rows stay in the table with a "notice" badge and no deadline or award parts. The pitch says "surfaces notices", not "finds more grants". Keyword recall of the notice pull is [uncertain].
10. **Feedback button.** An optional "pick 3 good, 3 bad" after results nudges the weights. Never required to start.
11. **Named weakness.** Recall versus shortlist length, measured on our pool. Stale plans and missing sources (SAM.gov, USDOT page) go on the limits slide and in the Q&A sheet. Pilot ask: a few agencies, a named contact labelling results, threshold retuned from their labels.
12. **Test pool.** Three agencies, 20 items each, two labelers per item, 70% recall pass bar. Labels are called "team-labelled", never ground truth. The pool is drawn and written down before scoring. Agencies: Department of Public Schools (education), Department of Environmental Quality (environment), Department of Health and Human Services (health). Claude chose these on Kent's instruction. They give the school bus case (education and environment) and a health contrast. DHHS plan text is partly OCR, so check its goals first.
13. **Signature tiers.** A second axis from the qualifier's `tiering.js` (writer, supervisor, secretary or legislature, plus university-led). Structured fields give a first-pass tier for all rows, badged "from listed fields". The qualifier's labeling prompt upgrades flagged and top-N rows through Azure OpenAI, cached, badged "from announcement text". An unknown signal reads "unknown" and never defaults to Tier 1. Labeled-row cap lives in `00_config.R`. If the labeling pass is untested at the code freeze, fields-only ships.
14. **Scenario presets.** A text box and presets in the demo, for example "small agency, no grants staff" and "large agency with a grants office". Values in `00_config.R`.
15. **Pool label set and cut order.** Labels: relevant, maybe, not relevant, fixed before labelling. If time runs short, cut in this order: feedback button, LLM tier upgrade, presets. Never cut the table, fit score, flag rule, quote check or recall test.

## Open items
- Verify applicant-type codes against the Grants.gov list (Kent).
- Sample 30 of the 348 unclassified USAspending recipients and count errors (Kent or Everett). The "NC has won before" column carries [uncertain] until then.
- Sample 10 of the 70 far-future-date items (decision 8).
- Azure OpenAI deployment (embeddings and chat) and the $500 spend cap: Marco. Blob upload only after Kent says yes.
- Marco's branch needs main pulled in.

## Order of work
1. Fri night: roles recorded in `_team/docs/RUNBOOK.md`; Marco's Azure steps.
2. Sat morning: pool rules and label sheet; `data/manual/criteria.csv`; `Rscript R/01_profile.R`; the pipeline (embeddings, score table, flag rule, hide-ineligible, unknown handling, notice rows, rolling dates); `Rscript R/check_facts.R` and tests. Teammates label the pools in parallel.
3. Sat 1:00 PM gate: working ranking per agency, recall number, Clean School Bus (CFDA 66.045 [uncertain]) appears for education and environment, deterministic rerun.
4. Sat 1:00 to 7:00 PM: Azure reasons with the quote check; the JS tool with agency picker, sliders and breakdown; tiers; presets; feedback button only if time holds. Fact sheet, field notes, slide brief, Q&A sheet from verified numbers only.
5. Sat 7:00 PM code freeze. Sun before 9:00 AM submit slides, field notes, repo and product link.

## Amendments after the plan review (Kent, Fri Nov 6 night, grilling interview)
These override the numbered decisions above where they differ. Settings live in `src/R/00_config.R` ("Evaluation, refresh and feedback").

| # | Decision | Changes |
|---|---|---|
| A | Fit is scored first by keyword similarity (TF-IDF or BM25) in R, behind one swappable scoring function. Azure embeddings replace it when Azure OpenAI works; recall is reported for both. | Decision 7 no longer waits on Azure OpenAI |
| B | Pool labels: hand-labelled first, then labelled by Kent's local model. Model labels may scale the pool beyond the hand set only if, on the hand set, the model catches at least 80% of hand "relevant" items and Cohen's kappa is at least 0.6 on relevant (relevant plus maybe) versus not relevant. If it fails, report recall on hand labels only and report the failure. | Decision 12 labels |
| C | Pool draw: per agency, half from the agency's matching Grants.gov `category` (Education for DPI, Environment for DEQ, Health for DHHS), half random from the rest. Fixed seed; the draw script is committed before any scoring runs. Clean School Bus and other named cases are separate named tests, not pool items. | Decision 12 draw |
| D | No threshold tuning on the pool. The flag is the top N = 10 per agency per window. | Decision 3 (tuning on the reported pool was circular) |
| E | The window is user-selectable in the UI, default 2 weeks. Evaluation is a backtest over closed items since 2024-11-06, replayed window by window at 2, 4 and 6 weeks. | Decisions 3 and 11 |
| F | The curve shows two lines: all catches, and in-time catches (at least X = 21 days left before close at the end of the window). The gap between the lines is the case for frequent refresh and deadline alerts. X = 21 is a team assumption, not a sponsor number. | Decision 11 named weakness, now measured |
| G | A daily Azure Container Apps Job (`MODE=job`) pulls new Grants.gov items (cached), scores them, writes `payload.json` to Blob and stamps "data as of". In the demo, trigger the job once by hand if the schedule cannot be shown. | Decision 6 refresh |
| H | Bonus 2 (deadline alerts): an in-app "Closing soon / New since last visit" panel. Last visit is kept in the browser's localStorage. No email. | Deadline alerts |
| I | Bonus 3 (feedback): `POST /feedback` on the Container App accepts agency, opportunity ID and good or bad only (no free text, no personal data), with input validation and a rate limit, stored in Azure Table or Blob. The daily job applies Rocchio profile updates (good items added to the agency profile, bad items subtracted, fixed small weights). Pin and hide are the instant visible effect. Measured by simulating feedback from half the hand labels and reporting the in-time recall change on the other half. | Decision 10 |
| J | Bonus 1 (coverage): the backtest catch counts from E and F. "Missed" keeps the meaning in decision 2. | Decision 2 |
| K | Outside test: a mentor at the Sat 2:00 to 4:00 PM drop-ins (discovery sponsors are not there) does one timed task: find one grant to act on for DPI or DEQ. Log confusions and one change made because of it in the field notes; call them mentors, not agency users. Needs a clickable build by 2:00 PM. | Understand gap |
| L | Cut order, first cut first: presets, LLM tier upgrade, model-label scale-up, Azure chat reasons (keyword snippets shown instead), feedback endpoint plus Rocchio, Azure embeddings swap (keyword stays; embeddings go on the roadmap). Never cut: keyword-fit table with the agency picker, hide-ineligible and "check eligibility", the in-time recall curve on hand labels, the daily job, the closing-soon panel, and the quote check on any reason that ships. | Decision 15 |

### Still open
- Judges' access to the private repo: add them as collaborators, or submit a zip or public mirror without `api_keys.env`. Check what the Final Submission form expects.
- School bus "about one month" application window is from discovery notes; verify against Grants.gov before it goes on a slide.
- X = 21 days is a team assumption; say so in Q&A.

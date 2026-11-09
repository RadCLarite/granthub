# Requirements: ranked, traced, with what we left out

Rubric target: Frame, level 4 (reframed as we learned; requirements prioritized and traceable to sponsor input; scope held). Sources: `planning/07_discovery_findings.md` (our notes of the Fri Nov 6 discovery session, not verbatim quotes), `saturday/02_decisions.md`, `src/docs/fact_sheet.md`. Evidence status is read from those documents; re-check against the live tool before claiming it on a slide.

## How the problem changed
| Before the discovery session | What the sponsors said | What we built instead |
|---|---|---|
| Rank grants by how well they match an agency's plan | Time and "worth the effort" decide whether anyone applies; most agencies have no one whose job is scanning | Eligibility became its own step (hidden with a quoted reason, or "check eligibility"); rows show days left and who must sign; ranking is by plan fit with deadline and signature tier visible |
| Teach the tool by having each user rank 10 sample grants | More questions to users is bad | Onboarding ranking dropped or shrunk [check what shipped in the live tool] |
| Search Grants.gov | Grants.gov alone "is not comprehensive" | Added USAspending, Federal Register, SAM Assistance Listings and state strategic plans; SAM.gov postings are not loaded (README, Known limits) |
| Prove it works with a model's labels | The first held-out check failed (kappa 0.44 in-sample) | Labels kept out of the ranking; the notice reader is advisory only (decisions 3 and 9) |

## Requirements, in priority order
Priority is our reading of what the sponsors stressed most: must = pilot fails without it; should = clearly asked for; could = stretch.

| # | Priority | Requirement (sponsor input, paraphrased from notes) | Where it is met | Evidence |
|---|---|---|---|---|
| 1 | Must | Save time, never add work | One required choice (agency), then a ranked list; no setup questions | Live tool, README "What it does" |
| 2 | Must | Fast and simple; waiting minutes fails | Static page served by `ffm-app`, payload prebuilt; warm 0.09 to 0.15 s, cold start 38 s at zero replicas, min replicas set to 1 | `src/docs/azure_setup.md` |
| 3 | Must | Sort eligibility, not the person | Hard filter with exact quote, or "check eligibility" | Fact sheet rows 7 and 8 (16,288 pairs marked check eligibility; others hidden with a reason) |
| 4 | Must | Rank by payoff versus effort, not fit alone | Award ceiling and signature tier (writer, supervisor, leadership) shown per row; 26 Top 10 rows need leadership | Fact sheet rows 24 and 25; 887 open items have no award ceiling and say "not listed" (row 6) |
| 5 | Must | Deadline and time to act on every match | Days-to-deadline and status badges; 71 Top 10 rows close within 14 days across 24 agencies | Fact sheet rows 17 and 18; decision 12 |
| 6 | Must | Use public data only; privacy | Opportunities, plans and county measures are public; the LLM only labels text with a quote and never ranks or hides | Decision 9; README constraints |
| 7 | Should | Cross-agency by design, easy to hand over | 32 agencies in one payload; README "How to extend" for adding an agency or rule; 89 tests, 49 fact checks | Fact sheet rows 2 and 9; `docs/HANDOVER.md` |
| 8 | Should | Know how many opportunities are missed (coverage) | Award-history backtest on 157 won programs: 61 reach the Top 10 (39%), 98 reach the Top 50 (62%) against 19.7% for soonest deadline and 14.1% for random | Fact sheet rows 26 to 29 |
| 9 | Should | Go beyond Grants.gov | USAspending, Federal Register, SAM Assistance Listings used; SAM.gov postings and foundations not loaded | README Known limits |
| 10 | Could | Draft the proposal | Out of scope, see below | Decision list |

## Deliberately left out, and why
- Proposal drafting: sponsors called it the top tier, but a checklist of requirements is all we can defend in a weekend, and a wrong draft is worse than none.
- Private foundations and SAM.gov postings: no clean bulk source found in the time available (SAM Assistance Listings are used instead).
- Accounts and server-side saving of user marks: no personal data to hold; marks stay in the browser and a de-identified copy goes to `/feedback` for the pilot measure.
- Letting marks change the ranking: not done. We could not test that it improves the list, so it is a pilot question, not a claim.
- Real cloud refresh: the daily job exists but runs as a dry run (see `README.md`, Daily refresh). We do not describe it as live.

## Scope held under pressure
- The 1:00 pm gate on Sat Nov 7 was the agency picker with a Top 10 and one backtest number; stretch items (match board, qualifier features) were ordered behind it in `saturday/02_decisions.md` (decisions 1, 11, 12).
- The backtest bar (50% of won programs in the Top 10, 4-week windows, 2 of 3 agencies) was fixed before looking at results and the failed first run is reported (fact sheet row 15).

# Q&A defense: weaknesses and tradeoffs

Rubric target: Evaluate, level 4 (evaluation built into the solution; tradeoffs defended with reasoning, not deflected). Every number comes from `src/docs/fact_sheet.md`. Say the weakness before the judge asks.

## Evaluation inside the product
- Each grant can be marked Pursue, Maybe or Skip. Each mark is sent, de-identified, to `/feedback` (agency, grant, rank, mark, random browser code). `app/pilot_scorecard.sh` turns the log into the pilot measure, shown as "Pilot measure" in My grants. Marks do not yet change the ranking.
- A pilot would read that measure after the first weeks: the share of Top 10 rows that staff mark Pursue or Maybe.

## Questions to expect, with the answer
| Question | Answer | Source |
|---|---|---|
| Does the ranking work? | On 157 programs agencies had actually won, 61 (39%) reached the Top 10 and 98 (62%) reached the Top 50, in 4-week windows over 12 agencies. A plain soonest-deadline sort reached 19.7% and a random Top 10 reaches 14.1%. | Fact sheet rows 26 to 29 |
| Did it pass your bar? | Not on the run we set beforehand. The bar was 50% of won programs in the Top 10, in at least 2 of 3 agencies; that run met it in 1 of 3 (DPI 2 of 3, DEQ 3 of 7, DHHS 4 of 11). After three ranking fixes made for other reasons (embassy filter, region list, tribal-title rule) it reads 2 of 3, but the denominators move with the ranking, so we say both and do not call it a pass. | Fact sheet row 15 |
| Did a simple sort beat it? | In the first 3-agency test the soonest-deadline sort beat the model in all three. In the 12-agency test the ranking is ahead (39% against 19.7% at Top 10). We tell you both. | Fact sheet rows 16 and 29 |
| Is the test biased in your favor? | Yes. Repeat funding favors any test built on past awards, and we tuned the text-fit setting after seeing results (current 60 of 157, best of 9 settings 64 of 157), so treat the gain as optimistic. | Fact sheet row 30 |
| Is it useful early enough to act? | 41 of the 61 catches had at least 21 days left at the end of the window. That is the number that matters, not the raw catch rate. | Fact sheet row 32 |
| Where does it fail? | Keyword matching misses grants worded differently from the plan and makes odd matches; region comes only from title and text, so another state's grant can slip through; the "NC has won this" track record undercounts (31 recipient matches confirmed); only DHHS and DMVA have a capability table; four plans are old. | README Known limits |
| Did you test it with agency staff? | No. Testers were other undergraduates, consultants, government workers and other adults, none from an agency or OSBM. We say so. | `FIELD_NOTES.md` |
| Why not let the AI decide eligibility or tier? | The model only labels text with a quoted passage and never hides or ranks. An early label check failed (kappa 0.44 in-sample), so labels stay out of the ranking. A person decides, and rules live in one file. | Decisions 3 and 9 |
| What does missing data do? | Shows "not listed". 488 open items have no usable close date and 887 no usable award ceiling; we never fill in a value. | Fact sheet rows 5 and 6 |
| Is the cloud refresh real? | Not yet. The daily job is deployed and runs as a dry run on a baked payload; fetching new postings is a manual step. We name that as the next step. | README Daily refresh |
| What would you do with a pilot budget? | See `docs/PILOT_PLAN.md`. | |

## Tradeoffs, stated as choices
- Hide versus flag: items clearly ineligible are hidden with a quoted reason; uncertain ones are shown as "check eligibility" so we never silently drop a real opportunity (cost: a longer list).
- Rules over a model for tiers and eligibility: explainable and reproducible, but they miss cases a model might catch.
- Public data only: no privacy risk, but we cannot see which grants an agency is already pursuing.
- Exploratory evaluation reported as such: weaker headline, higher trust.

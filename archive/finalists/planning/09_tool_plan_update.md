# Tool plan update: proposals for Kent

> **Saturday Nov 7 update:** `../saturday/` (start at `../saturday/README.md`) overrides this file where they differ.

Written Sat Nov 7, about 12:30 am, by Claude with Marco, from a grilling session after the seven reviews (`testing/triage_20261106_full_review.md`). **These are proposals.** `planning/08_product_decisions.md` stays the source of truth until Kent accepts them. Reviewers are simulated personas, not user evidence. Marked `[reported]` means Marco reported it and the files are not in the repo.

## Goal
Serve **all agencies** in the tool by submission, on Azure, with a person making the final call. Measure most deeply where evidence exists, and show plainly where it is thin.

## Proposals at a glance
| # | Proposal | Why | Criterion | Changes in 08 |
|---|---|---|---|---|
| 1 | Keep the qualifier look; agency picker is the only required step; setup and sliders collapse under "Adjust" | Ease of use came up most at the sponsors' Q&A (Marco); first-time user stops at setup controls (reviewer 06) | Understand | Refines 1, 5, 14 |
| 2 | Action tiles lead: Top 10, Closing soon, New since last visit, Check eligibility, Coming up. Signature piles become a smaller filter row with an Unknown pile | Sponsors' problem is noticing in time; Tier 1 was a default bucket (05) | Understand, Solve | Refines 13 |
| 3 | Forecasts get their own "Coming up (not open yet)" tile; Top 10 holds open items only; forecasts stay out of the in-time count | Earliest warning without looking actionable (02, 05, 06) | Evaluate | Refines D |
| 4 | Four-step eligibility: codes, fixed text rules, notice reader, accuracy gate | Codes alone leave about 36% unclear | Solve | Refines 4 |
| 5 | Local model labels relevance offline; Azure serves them | Must run on Azure; labels are precomputed | Solve | Refines B |
| 6 | Award history backtest is the main evidence; no new labeling | Team labels were called circular (01, 02); no labeling time | Evaluate | Refines 12, C, E |
| 7 | Keep feedback and Rocchio in amendment L's order; Pursue and Pass send the good and bad signals | Marco's call; also adds the human decision button the Starter Kit says never to cut | Solve | Adds to I |
| 8 | Pilot: tool open to all agencies, measured in three, OSBM names the owner | Answers who, what it replaces and how we would measure misses | Drive Impact | New |

## First screen
- Pick an agency. No other setup. Safe defaults apply.
- Each row: days left as the headline, plain eligibility, one-line reason, next step.
- Plain words on screen: "You can start", "Needs your boss", "Needs leadership", "Unknown". Define forecast, cost share and ceiling where they appear.
- A count line accounts for everything, for example "42 hidden as not eligible, show them". Tiles overlap, so they will not add up.
- A thin Top 10 shows fewer items. It is never padded.
- `Adjust` holds weights, presets and the window. Map and other views stay as tabs.
- Show plan quality by agency: stale, thin or cross-cutting. No agency is ranked down for it.
- Next step per item, built from eligibility, signature and days left. This is the answer to "how does a lead become a better application". It does not draft proposals.

## Eligibility
Measured on 1,472 open and upcoming items (quick pattern match; codes still need verifying):

| Applicant list | Items | Starting label |
|---|---|---|
| State governments listed | 837 | Yes, listed |
| "Other" or "unrestricted", no state | 537 | Ask |
| Closed list without state, or blank | 98 | No, or Ask if blank |

1. **Codes.** Closed lists without state are No, adjusted by agency type: higher-education-only is No for DEQ and may be Yes for the UNC System and Community Colleges. Tribal-only is No for all.
2. **Fixed rules.** Clear phrases and funder patterns. A first pattern test left 285 of 427 "other" items unresolved, so rules alone cannot do it.
3. **Notice reader.** Labels: state agency can lead, partner only, not eligible, unclear, with an exact quote a script checks. Code maps the label to Yes or No. **Uses Azure OpenAI, created Sat 12:50 am and tested; confirm at 9:00 that it is ours to use.** The local model was never tested on eligibility `[reported]`.
4. **Accuracy gate.** A label sorts automatically only after a hand check of about 100 items at 90% or better for Yes and for No [proposed bar]. Hand-check capacity is short, so scale this to what the team can do, or everything stays Ask.

Items are hidden only with a verified quote or a clear code. Caution: the qualifier's model matched hand labels only 67% on a similar label ("administrable by a state agency"). **If Azure OpenAI is refused, or the gate fails, steps 1 and 2 still run, unresolved items stay Ask, and the pitch says so.**

## Relevance model `[reported]`
- `qwen2.5:14b` through Ollama, prompted, not trained. Labels `relevant`, `maybe`, `not relevant`, plus one checked quote. Code: `drafts/claude/eval/model_label.R`, prompt `evalpool-v3`. **Not in the repo yet; please push it.**
- Cached in `data/cache/llm/`, written to `model_labels/full_pool_labels.csv`, then into `payload.json`.
- Current gate **fails**: kappa 0.44 against 0.60. It caught 3 of 3 hand "relevant" and 3 of 9 hand "maybe". Those numbers are in-sample, because prompts v2 and v3 were written from the same 60 items.
- Run is partial: 3 pool agencies, stopped, resumes from cache. Labeling all agencies is about 45 hours, so not possible by Sunday.
- **Rule:** keyword fit is the base. Model labels are an optional layer. With no held-out set they cannot pass, so they stay off or read "unvalidated". For agencies without them the tool says so.
- Pitch wording: "labels are precomputed locally, Azure serves them."

## Evaluation, no new labels
| Evidence | What it shows | Limit |
|---|---|---|
| **Award history backtest** (main) | Would the top 10 have surfaced programs an agency really won, and in time? Closed rows: Public Schools 30 (8 programs), DEQ 47 (15), DHHS 133 (38) | Program level, not the exact notice. Favors repeat funding. Some noise. Not a "missed" count |
| 60 hand labels | Keyword fit against people's judgment | Valid only if keyword fit is not tuned on them. Report plain counts: with so few relevant items a 70% bar means little |
| Named cases | Pass or fail: DERA `EPA-OAR-OTAQ-26-01` appears, tribal-only hidden, 2099 reads unknown | Handful of cases |
| Rank stability | Does the top 10 hold when weights move by 0.5? | Stability is not correctness |
| Mentor test, 2:00 pm | Can an outsider find a grant? | Mentors, not agency users |

Rules: award data stays **out of the score**. Kent sets the pass bar **before** the script runs. Say "would have flagged" and "programs this agency has won". Show counts and a range beside each result. A quick name match found award rows for about a dozen agencies with 10 or more, and little or none for many small agencies, so a proper name map is needed. Report by agency, never as one statewide number.

My `drafts/claude/eval` sheets (6/6/8) are retired by this. Keep the scoring code; rework it for award history.

## All agencies
- 34 plans in the picker. Two are cross-cutting (State Board of Education Plan, Guiding Principles): decide whether they belong in the picker. Four are stale (Auditor, Elections, Wildlife, Commerce). 12 have three or fewer goals.
- Keyword fit, deadlines, tiles and code eligibility work for all 34 from goal text.
- Depth varies, and the tool says so: award evidence for about a dozen, model labels for three.

## Azure work
- Daily job (`MODE=job`) refreshes, scores, writes `payload.json` to Blob and stamps "data as of". This is the core cloud story.
- Container App serves the JS tool. Shiny stays as the fallback.
- `/feedback` per amendment I, with validation and rate limit. It needs a written answer on what it stores, who reads it, and retention (reviewer 04).
- Azure OpenAI: created and tested, not wired in. Confirm at 9:00. Uses: notice reader first, then chat reasons, then embeddings. About $0.60 per pass over all open items, estimated.

## Pilot ask
- 60 days. The tool is open to all agencies.
- Measured in three (Public Schools, DEQ, DHHS), with a named coordinator in each who keeps checking manually. That gives the true baseline for "missed" we cannot get this weekend. Add one small agency, since small agencies miss the most.
- Replaces ad hoc scanning and the survey that did not work.
- Monthly cost computed from Azure list prices before it goes on a slide.
- **Ask OSBM to name one owner.** Do not invent one. State the skills needed: Azure, the daily job, and rerunning labels.
- Agree the success measure before it starts.
- Handover for labels: model name, Ollama version, prompt version, cache, rerun command.

## Must fix before the 1:00 gate
From the triage: write `criteria.csv`; make `00_config.R` fail loudly on toy data; fix `score.R` (drop-and-rescale, 2099 dates, ceiling 0 as unknown, duplicates, all-zero weights); apply eligibility rules so codes 25 and 99 are not hidden; add agency and window to the ranking; replace the Clean School Bus gate case.

## Saturday order
1. 9:00: confirm Azure OpenAI is ours to use; Kent rules on the questions below.
2. To 1:00: criteria, `score.R` fixes, keyword ranking for all agencies, eligibility steps 1 and 2, award backtest, payload.
3. To 2:00: first screen on Azure, clickable for the mentor test.
4. 2:00 to 7:00: daily job, closing-soon panel, then notice reader if approved, then feedback, then reasons.
5. Cuts follow amendment L. Never cut the items it protects, plus the decision button.

## Questions for Kent
1. Accept proposals 1 to 8?
2. Does replacing the pool with award history change the 1:00 gate, and what pass bar applies?
3. Does the notice reader move ahead of "Azure chat reasons" in amendment L?
4. What is the hand-check capacity for eligibility, given no time for new labels?
5. Do cross-cutting plans belong in the picker?
6. Does DERA replace Clean School Bus at the gate?
7. Who pushes `model_label.R` and the gate outputs?

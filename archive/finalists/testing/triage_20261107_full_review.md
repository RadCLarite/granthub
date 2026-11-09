# Final Quest review: Federal Funds Matchmaker

For Noah and Kent. Read-only review, Sat Nov 7. 25 reviewers ran and none is missing. They raised 338 findings. A skeptic checked each one: 240 confirmed, 10 refuted, the rest uncertain or low. I spot-checked the five highest-impact findings myself (listed in section 8).

Reviewer short names used below: hostile-judge, data-critic, test-breaker, user, supervisor, director, deputy-sec, dhhs-writer, fed-PO, mentor, it-architect, nongrants, osbm-analyst, osbm-sponsor, state-dev, field-notes, number-tracer, solve-req, eval-method, threat, demo-ux, code, submission, frame-req, discovery.

## 1. Bottom line

- **Not a pilot budget today.** The app is live and the pipeline runs and can be reproduced. But there is no slide brief, no pilot ask and no Q&A answers. The fact sheet holds no evaluation numbers. A budget director could not say what they are approving.
- **The team's own evidence works against the ranker, and the pitch has not dealt with it.** At 4 weeks the tool clears the 50% bar for DPI only (2 of 3 programs). DEQ is 3 of 7 and DHHS is 4 of 11, so the 2-of-3 rule fails. Picking the 10 soonest deadlines from the tool's own top 50 beats the ranker in all 9 agency-window rows. Random 10 ties or beats it in all 9.
- **Biggest single risk: overclaiming on stage.** The danger is a demo that implies AI matching, a daily refresh or "would have caught the school bus" while a judge opens DPI. DPI's top 10 is all "Ask": rank 1 is a Tribal Colleges program, rank 6 is a West Point announcement, and ranks 4 and 5 cite a "Revere Public School Educators" goal. Told honestly ("we tested it, it lost to a deadline sort, here is what that means and what a pilot would measure"), this is Evaluate credit. Told any other way, it costs credibility on every criterion.

## 2. Scorecard

| Criterion | Median (range) | Reviewers who scored | Reason |
|---|---|---|---|
| Understand | 2 (2 to 3) | 19 | One Friday discovery session in paraphrase. The mentor log is blank, no real user has seen the tool, and many decisions trace to Kent's interview rather than to sponsors. |
| Frame | 3 (2 to 4) | 24 | The problem and the 10 sponsor requirements are clear. But the default rank is fit only (payoff, cost share and runway all have weight 0), and the success bar moved from 70% to 50%. |
| Solve | 2 (2 to 3) | 23 | The live Azure app and a reproducible pipeline exist. But reasons are plan headings only, the top 10 has visible false positives, the daily job is a stub and Azure OpenAI is not wired in. |
| Evaluate | 2 (2 to 3) | 23 | Good method: bar set in advance, intervals, two baselines, label gate. But both tests fail, the backtest denominator comes from the tool's own top 50, and none of it is on the fact sheet. |
| Drive Impact | 2 (1 to 2) | 22 | No pilot ask, owner, cost or Monday step. The Q&A sheet and slide brief are empty templates. |

## 3. Fix before 9:00 am Sunday

Code freeze is Sat 7 to 8 pm (00_timeline.md: "Fixes only"). Rows marked **[before freeze]** change code or payload and must merge by 7 pm. Everything else is writing and can land Saturday night, but the slide brief has to exist before slides start at 8 pm.

| # | Problem | Where | Criterion | Sev | Raised by | Fix | Effort | Owner |
|---|---|---|---|---|---|---|---|---|
| 1 | The backtest fails the team's own bar and loses to the deadline baseline in 9 of 9 rows. None of this is on the fact sheet, so under the team's rule it cannot go on a slide. | data/processed/backtest_result.csv; src/docs/fact_sheet.md | Evaluate | High | 17: hostile-judge, data-critic, test-breaker, supervisor, director, deputy-sec, dhhs-writer, mentor, nongrants, osbm-analyst, osbm-sponsor, field-notes, number-tracer, eval-method, threat, submission, frame-req | Add fact rows: won/caught counts, intervals and both baselines per agency at 4 weeks, plus the line "bar 50%, set in advance; result 1 of 3; deadline sort did better". Make this the named-weakness slide. Say what the tool adds (eligibility hiding, plan link), not recall. Do not rerun until it passes. **[before freeze]** for facts.csv. Also confirm the result postdates the 10:19 program-map rebuild: the result was committed at 10:02 (number-tracer, uncertain). | S | Kent (facts), Everett (numbers, rerun check) |
| 2 | No slide brief, no pilot ask (owner, agencies, weeks, cost, success measure, manual monitoring kept running alongside), and the Q&A cheat sheet is blank, including "biggest weakness" and "Monday". | deliverables/ (template only); src/docs/qa_cheatsheet.md | Drive Impact | High | 11: hostile-judge, supervisor, director, deputy-sec, mentor, osbm-sponsor, number-tracer, threat, submission, frame-req, osbm-analyst | Write deliverables/slide_brief.md: ask first, one figure, a 90-second demo script, the limits slide from row 1, and a one-sentence pilot. Fill the Q&A rows from section 5, each citing a fact number. Unknown cost goes in as "not measured". | M | Kent (brief, per kent.md step 7); Q&A Kent |
| 3 | Visible false positives in the first screen. DPI: TCUP rank 1 (fit 1.0), West Point BAA rank 6, NSF research grants, 10 of 10 "Ask". Commerce rank 1 is USDA SBIR. DHHS ranks 1 to 4 are NIH research notices. DEQ shows out-of-region CESU agreements and a paperwork notice. 61 Federal Register notices sit in the top 10 pool. | data/processed/payload.json; src/R/00_config.R (ELIG_TEXT_NO); src/R/11_build_payload.R:52 | Solve | High | 13: hostile-judge, test-breaker, deputy-sec, dhhs-writer, fed-PO, nongrants, osbm-analyst, solve-req, demo-ux, supervisor, code, it-architect, data-critic | Add tribal-college, "institutions of higher education only", SBIR/STTR and service-academy phrases to the text rules. Select status == "posted" for the top 10. Hand-check 10 rows each for DPI, DEQ and DHHS and report the count that are plausible state applicants. Pick the demo agency only after reading its list. **[before freeze]** | M | Kent |
| 4 | The only "reason" is a plan-goal heading, with no notice quote, and some are wrong. DPI cites "Revere Public School Educators", which is non-NC text sitting in the DPI plan file. DHHS ranks 5 to 8 (juvenile justice, preschool, animal food) all cite "Behavioral Health Crisis Care". opp_snippet is in every row but never shown. | src/tool/matchmaker.html:117; data/processed/agency_plan_text/all/department_of_public_schools.txt | Solve | High | 12: hostile-judge, user, supervisor, deputy-sec, dhhs-writer, fed-PO, it-architect, nongrants, osbm-analyst, solve-req, threat, demo-ux | Render opp_snippet as an "In the notice:" line next to the plan line. Remove the Revere lines from the DPI plan goals. On stage, call it "keyword match, plan goal shown", never "AI rationale". **[before freeze]** | S | Marco (UI), Kent (plan text) |
| 5 | The Azure story overclaims. The daily job (MODE=job) only prints a line. Azure OpenAI is created but not wired in (reader_label is null on 960 of 960 rows, signature_tier is "unknown" on 960 of 960). Data-handling terms are unread. | app/entrypoint.sh:2-5; src/docs/azure_setup.md:50,162,166,194 | Solve | High | 15: hostile-judge, supervisor, mentor, it-architect, solve-req, threat, state-dev, osbm-analyst, osbm-sponsor, user, fed-PO, director, deputy-sec, dhhs-writer, demo-ux | Say plainly: Azure hosts the app and stores the payload, refresh is manual today, and the scheduled job is the first pilot task. Drop "AI-assisted", signature tier and "daily" from slides. Read the Azure OpenAI data-privacy page and write two sentences citing it, or say "not verified". | S | Kent (slides), Marco (azure_setup.md) |
| 6 | DERA, the showcase case, ranks only because a hand table lifts fit to 0.8. The DPI link is marked [uncertain], and the sponsors' Clean School Bus program has 0 rows. | data/manual/program_map.csv; fact_sheet.md row 14; matchmaker.html (map_note not shown) | Evaluate | High | 10: hostile-judge, data-critic, test-breaker, supervisor, dhhs-writer, mentor, osbm-analyst, osbm-sponsor, eval-method, number-tracer | Show map_note in the UI as "added by team rule". Report DERA's rank without the map if the pipeline gives it cheaply. On stage say "a related EPA program, surfaced by a hand rule", never "would have caught the school bus". **[before freeze]** for the UI | S | Marco (UI), Kent (rank number) |
| 7 | The backtest method flatters the tool. The denominator counts only won programs already in the tool's top 50. Both baselines draw from that same top 50. Hits are unioned across windows, and no window is restricted to awards made before it. | src/R/20_backtest_awards.R:80-82, 98-111 | Evaluate | High | 6: data-critic, test-breaker, dhhs-writer, mentor, eval-method, code | Do not rerun on a new design tonight unless Kent can supply the full closed pool, because the script reads only the top-50 file. State the limit beside the result. Note the result is worse than it looks: inside its own top 50, the tool's order loses to a deadline sort. | S (disclose) / L (rerun) | Everett, Kent |
| 8 | The held-out label check failed its gate: strict catch 0 of 1, lenient 3 of 6, labeler kappa 0.322 on 30 items. It is not on the fact sheet, so the "AI was wrong" story has no traceable number. | drafts/claude/docs/holdout/label_check_result.md; fact_sheet.md | Evaluate | Medium | 12: test-breaker, supervisor, director, dhhs-writer, mentor, osbm-analyst, field-notes, number-tracer, eval-method, threat, submission, data-critic | Add a fact row with the counts and the n=30 caveat, and say model labels are excluded from the payload. Lead the field notes' "AI was wrong" section with this result plus the DERA miss. | S | Kent (fact), Noah (field notes) |
| 9 | The field notes are a stale Friday draft ("none are built", 70% bar, 13 [TO FILL]). There is no real user or mentor evidence and saturday/mentor_log.md is an empty table. | drafts/claude/docs/field_notes_draft.md; saturday/mentor_log.md | Understand | High | 12: hostile-judge, supervisor, deputy-sec, mentor, osbm-sponsor, field-notes, submission, frame-req, discovery, director, nongrants, osbm-analyst | Rewrite status and success test to match saturday/02_decisions.md. Resolve or mark "not done" every [TO FILL]. Log each mentor slot that actually ran, with time and role. If no outside person used the tool, write that plainly. Never cite personas. | M | Noah (field notes), Matthew (mentor log) |
| 10 | Ranking is fit only (award_size, no_cost_share and runway all have weight 0), and the 14-day window is never applied. The top 10 mixes rows with 10 days left and 427 days left. award_ceiling is never displayed (887 open items have none). | data/manual/criteria.csv; src/R/11_build_payload.R pick_rows; matchmaker.html rowEl | Frame | High | 15: data-critic, test-breaker, user, supervisor, dhhs-writer, fed-PO, mentor, nongrants, osbm-analyst, deputy-sec, code, demo-ux, threat, osbm-sponsor, director | Do not change weights now: that would invalidate the backtest. Show "Up to $X" or "Amount not listed" and the close date on each row. On the slide say "ranked by plan fit; payoff and deadline shown, not scored". **[before freeze]** for the UI | S | Marco |
| 11 | The counts line misleads. open_total is null for all 32 agencies, so it reads "among the best matches loaded". Notice rows flagged in_top10 are filtered out, so some agencies show 2 to 4 rows. n_hidden_ineligible (98) is never used. | matchmaker.html:131-143; 11_build_payload.R:36-42 | Solve | Medium | 8: user, osbm-analyst, nongrants, solve-req, demo-ux, code, threat, persona-user | Add open_total to the payload. Fix the "below the top 10" arithmetic. Explain short lists in one line. Row 3's posted-only top 10 removes the notice gap. **[before freeze]** | S | Kent (payload), Marco (UI) |
| 12 | The root README is the Friday skeleton (a "hello page", "not built until needed"). The state-developer draft is stale. There is no install list or lockfile, so run_tests.R dies on a missing `here` package. The image needs an undocumented staging step. | README.md:8,15,54; drafts/claude/docs/README_state_developer_draft.md; app/Dockerfile | Solve | High | 6: it-architect, state-dev, solve-req, submission, demo-ux, persona-state-developer | Promote and correct the draft: what is built and not built, the stage-then-build steps, a package install block, the live URL, SAS expiry and renewal, and that refresh is manual. | M | Kent (README is unassigned in 03_contract.md), Marco (Azure section) |
| 13 | The test suite can never pass: run_tests.R has a hard-coded FALSE "agreement test pending". The R/JS agreement path (ranker.js, build_tool.R) is dead code for the new payload. | src/tests/run_tests.R:105-108; src/tool/ranker.js, build_tool.R | Solve | High | 4: test-breaker, state-dev, code, it-architect | Remove the FALSE check, or replace it with a payload-contract check (status == "posted" in the top 10, no duplicate titles per agency). Label the qualifier files as not part of the Matchmaker. Run tests and check_facts.R and put the pass line in the merge commit. **[before freeze]** | S | Kent |
| 14 | Uneven documentation is flagged, not handled. plan_thin is hard-coded NA, so the thin banner never fires. Fit is scaled so every agency's best item is 1.0. Stale-plan agencies (Commerce FY21-23) look as confident as the others. Evaluation covers 3 of 32 agencies. | src/R/11_build_payload.R:40; helpers_rank.R build_pairs | Evaluate | Medium | 10: test-breaker, user, supervisor, osbm-analyst, nongrants, threat, code, hostile-judge, osbm-sponsor, deputy-sec | Set plan_thin from plan text length or goal count. On the slide say "tested on 3 of 32; thin or stale plans untested" and propose an agency profile template for the pilot. **[before freeze]** for plan_thin | S | Kent |
| 15 | Data hygiene in the top 10. Raw HTML entities (&#8211;, &#699;) appear in titles. The two DHHS Navigator notices (ranks 9 and 10) have identical titles and scores. Standing announcements show "427 days left". Forecasts show a countdown with no "estimated" label. days_left is frozen at build time, so Sunday's counts are a day off. | payload.json; matchmaker.html:78-83 | Solve | Medium | 10: test-breaker, solve-req, dhhs-writer, user, fed-PO, demo-ux, nongrants, supervisor, it-architect, osbm-analyst | Decode entities in 11_build_payload.R. Compute days left in the browser from close_date. Show "over 1 year" and "estimated" for forecasts. Show opp_number so sibling notices can be told apart. **[before freeze]** | S | Kent (entities), Marco (UI) |

## 4. Organizer threats

| Threat | Status | Gap |
|---|---|---|
| False positives | Partial. Hiding ineligible items with a count and a drawer, the "Ask" badge and Pursue/Maybe/Pass all exist. | No confidence or fit band shown. Reasons are plan headings with no notice quote and no quote-check script. No measured false-positive rate. The DPI and Commerce top 10s show the threat on screen (rows 3 and 4). |
| False negatives | Measured, and it fails. The backtest has a bar set in advance, intervals and two baselines. | It fails the bar (1 of 3) and loses to the deadline baseline. The denominator is limited to the tool's top 50. "Won programs" measures repeat funding, not discovery. Keeping manual monitoring in a pilot appears only in notes (src/docs/organizer_materials_notes.md:33), not on any slide. |
| Uneven agency documentation | Partial. A stale-plan banner shows for 4 agencies. | plan_thin is never set. Nothing measures how plan quality affects match quality. No profile template or onboarding step is proposed. |
| Inconsistent data quality | Partial. Rolling, passed and 2099 dates are handled with notes. | Missing award ceilings (887 open items) are not shown. Raw entities and look-alike notices remain. No minimum reporting schema is proposed. Dates from 2030 on are treated as "rolling" even where sat_checks.csv found real end dates. |

## 5. Q&A prep: 10 hardest questions

| # | Question | Weak answer sounds like | A good answer uses |
|---|---|---|---|
| 1 | "Picking the 10 soonest deadlines beat your ranker in every row. Why fund the ranker instead of a deadline-sorted Grants.gov list?" | "Our ranking also considers fit." | backtest_result.csv (needs a new fact row). Admit it. Name what the tool adds: eligibility hiding, the plan link, one list per agency. Say a pilot would test fit plus deadline ordering. |
| 2 | "Did you pass your own test? And why did the bar drop from 70% to 50%?" | "We felt 50 was more realistic." | saturday/01_goals.md:33-36 and 02_decisions.md #7: set before the run, a team judgment, result 1 of 3. The 70% bar belonged to a different hand-label test that was dropped after the label gate failed. |
| 3 | "Recall on programs NC already won. How does that show what manual monitoring misses?" | "It would have caught X% of what we missed." | everett.md rules ("would have flagged", never "missed"). The script header admits the repeat-funding bias. A pilot runs alongside manual monitoring to get the real baseline. |
| 4 | "Why is a Tribal Colleges program number one for Public Schools, and a West Point announcement number six?" | "Eligibility says ask, so the user checks." | payload.json, fit scaled per agency (helpers_rank.R). The hand-checked plausible count from fix row 3 if done, or "not measured" if not. |
| 5 | "Where does AI help, and what data leaves state control?" | "AI-powered matching; Azure is secure." | azure_setup.md:166 (not wired in), the label check failure as the AI-was-wrong case, and model labels kept out of the payload. Privacy is [uncertain] until the doc is read; inputs are public notices and plans. |
| 6 | "Would it have found DERA without your hand map?" | "Yes, the tool found the school bus program." | fact_sheet.md row 14, program_map.csv. Clean School Bus has 0 rows in the data. Give the un-mapped rank only if computed. |
| 7 | "Your denominator only counts won programs already in your own top 50. How is that recall?" | "That's standard." | 20_backtest_awards.R:80-82. Name it as a limit, and note it makes the reported result look better than reality, not worse. |
| 8 | "Commerce's plan is FY21-23. How does a Commerce staffer know to distrust a 0.98 fit?" | "There's a banner." | payload plan_stale and plan_thin, plus "tested on 3 of 32" (fact sheet rows 2 and 12). Propose the profile template as the pilot fix. |
| 9 | "Which real user has used this, and what changed because of it?" | Quoting personas or "users told us". | saturday/mentor_log.md and the field notes. If none, say "one discovery session, no user test yet". |
| 10 | "What do I approve Monday, who owns it after Sunday, what does it cost, and who refreshes it?" | "OSBM can host it." | The pilot slide (to write), azure_setup.md cost estimates labelled as estimates, entrypoint.sh (refresh is manual today), and a named owner role. |

## 6. Lower priority and uncertain findings

**Demo operations**
- Set min replicas to 1 before the pitch to avoid the 38 s cold start. This is already planned (00_timeline.md:31). Confirm it was done Sunday morning.
- The read-only SAS expires about Nov 10. That is after the pitch, but a judge or pilot revisit later will get a 502. No last-known-good payload is baked into the image.
- Load the live URL once in a real browser on a hotspot before 9:00.

**Security and handover**
- api_keys.env and tasks/everett_api_keys.md are tracked in git. Decision 10's clean snapshot covers judges. Rotate the keys after the event.
- CRAN packages in the Dockerfile are unpinned.
- /shiny and /payload.json are public, with no auth or rate limit. State "public data only".
- The $500 budget is alerts only. No pilot monthly cost is stated.

**Product claims**
- Pursue/Maybe/Pass is saved in localStorage only, with no export. Do not call it a feedback loop.
- The closing-soon panel is on the "never cut" list but is not built.

**Eligibility rules**
- The negation regex has no word boundaries ("notice", "interstate agencies").
- Code 99 maps straight to "yes".
- Code 25 can be hidden by a text rule, despite the config comment saying it never is.
- The false-hide rate on the 3,030 hidden pairs is unmeasured.

**Facts and numbers**
- The 34 plans have no facts.csv row, and fact numbering is offset from facts.csv ids.
- f4 and f5 compute DEQ-only slices.
- Every fact row says "Kent to confirm".
- The stale "723 of 1,472" figure is in testing/context.md and the reviewer specs.
- SAM listings: 2,873 vs 2,875 is unreconciled.
- REF_DATE is a day behind PAYLOAD_AS_OF.

**Figure**
- The backtest figure subtitle is clipped (confirmed by supervisor).
- No n, baselines or plain agency names on the figure (uncertain for some reviewers).
- The in-time numbers are plotted but not written to the CSV.

**Config hygiene**
- PASS_PCT and the label-gate thresholds live outside 00_config.R.
- No sensitivity check on GEO_PENALTY 0.5, MAP_FIT_FLOOR 0.8 or IN_TIME_DAYS 21.

**Docs and logs**
- AI_USAGE_LOG.md has a blank row and rows below the notes block, and several rows still say "pending".
- The diagrams predate Saturday.
- notes/vault/Solveathon_WeekendLog.md names a mentor and says "5 minute limit".

**Repo clutter**
- Qualifier tool files and the /tool.html link confuse which product this is.
- Per-person duplicate CSVs sit in src/docs.

**Uncertain and worth one check**
- Whether 66.039 is in the DEQ/DPI won set, which would mean the program map raises backtest hits.
- Whether DHHS in-time recall changes at 14 vs 21 days.
- Whether an un-mapped DERA rank can be produced.
- Cross-agency duplicates: one notice is in 4 agencies' top 10, with no "also flagged for" note.

## 7. Where the AI reviewers were wrong

- **deputy-sec-1, nongrants-7: the live URL shows "STUB DATA".** Wrong. The banner is hidden unless the payload says stub. A fetch tool that does not run JavaScript saw the raw HTML. (fed-PO-11, dhhs-writer-10 and threat-9 made the same error, rated uncertain.)
- **deputy-sec-5: the UI does not warn on stale plans.** Wrong. matchmaker.html:136 shows the banner.
- **deputy-sec-12: hidden items appear only as a count.** Wrong. A "Hidden as not eligible" drawer lists them.
- **fed-PO-8: raw HTML entities show in snippets.** Snippets are never rendered. The entities are real but only visible in titles (section 3, row 15).
- **user-8: cold start is unplanned.** Min replicas 1 is already scheduled (00_timeline.md:31).
- **director-7: judges will see committed keys.** Decision 10's clean snapshot excludes api_keys.env and git history.
- **demo-ux-12: the committed app.R does not serve the matchmaker.** stage_proof_assets.sh copies matchmaker.html to www/index.html.
- **submission-8: toy data can be ranked silently.** stop_if_toy in 00_config.R blocks it.
- **threat-11: the stale field notes are a defect.** The file is a dated Friday draft in drafts/. The real gap is the missing update (row 9).
- **data-critic-12 (sub-claim): the fact sheet cites the wrong check_facts path.** The path is correct.

The pattern is worth putting in the field notes. Three or more reviewers judged a JavaScript page from a non-JavaScript fetch. Several treated a dated draft as the submitted file.

## 8. Coverage

**Reviewers that ran (all 25):** hostile-judge, data-critic, test-breaker, persona-user, persona-supervisor, persona-director, persona-deputy-secretary, persona-dhhs-grant-writer, persona-federal-program-officer, persona-industry-mentor, persona-it-architect, persona-nongrants-staffer, persona-osbm-analyst, persona-osbm-sponsor, persona-state-developer, field-notes-auditor, number-tracer, solve-requirements-auditor, evaluation-methodologist, threat-coverage-auditor, demo-ux-reviewer, code-correctness-reviewer, submission-readiness-checker, frame-requirements-reviewer, discovery-trace-auditor. Persona reactions are simulated and are not user evidence.

**What no one could assess:**
- **Live behaviour in a browser.** Clicks, phone layout and warm or cold timing were not tested. Whether the deployed Blob payload equals data/processed/payload.json is unknown.
- **Test results.** Several reviewers hit the missing `here` package, so neither run_tests.R nor check_facts.R pass status was confirmed. By reading, run_tests.R cannot pass (section 3, row 13).
- **Slides and pitch flow.** None exist.
- **Azure state.** Spend, role assignments, the current replica count and whether min replicas was changed are unknown.
- **Real user or mentor feedback.** None is in the repo.
- **Whether backtest_result.csv reflects the post-10:19 program-map ranking.**
- **Raw label sheets and the held-out key.** These were read only through the summary file.

**My spot-checks, all consistent with the merged findings:**
- backtest_result.csv: all 9 rows. The deadline baseline beats the tool in 9 of 9, random ties or beats it in 9 of 9, and at 4 weeks only DPI clears 50%.
- 20_backtest_awards.R:78-111: the denominator and both baselines come from the top-50 `sub`.
- fact_sheet.md: rows 1 to 14 are pipeline counts only.
- qa_cheatsheet.md: every answer cell is blank.
- deliverables/: holds only the template.
- matchmaker.html rowEl: renders the plan goal only, with no snippet, ceiling or map_note.
- payload.json DPI and DHHS top 10s: DPI is 10 of 10 "Ask", with TCUP, West Point, and Revere at ranks 4 and 5. DHHS ranks 5 to 8 all cite Behavioral Health Crisis Care, and ranks 9 and 10 have the same title and score.
- 03_contract.md and people/*.md: used for owners.
- QUEST_BRIEF.md: used for the four threats.

Relevant files:
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/data/processed/backtest_result.csv
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/src/docs/fact_sheet.md
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/src/docs/qa_cheatsheet.md
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/src/R/20_backtest_awards.R
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/src/tool/matchmaker.html
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/src/R/11_build_payload.R
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/drafts/claude/docs/field_notes_draft.md
- /Users/noahgoldfish/Documents/GitHub/SolveAThon_2026/Finalists/saturday/03_contract.md
# Full-project review triage, Sat Nov 7, 2026 (10:52 am)

26 one-shot reviewers ran over `Finalists/` at main `95fed84` (transcripts 08 to 33 in `testing/transcripts/`). Run by Marco's Claude Code session: Opus 5.5 as review manager, every reviewer a Sonnet 5.5 subagent, three at a time. The manager ran the tests once, briefed each reviewer, and spot-checked at least one claim from every reviewer against the files (results below). Persona findings are hypotheses, never user evidence. Everything here is a proposal for Kent to confirm.

**Time check:** building stops 6:00 pm (`saturday/00_timeline.md:23`). Submission Sun 9:00 am. About 7 hours of build time left when this was written.

## Checks the manager ran (exact output)
- Fresh checkout, README order: `run_tests.R` and `check_facts.R` both **crash** ("using TOY EXAMPLE data", "criteria point at columns that are not in the items"). Cause: `data/processed/items.csv` is gitignored (`.gitignore:7`) and only `R/10_run_ranking.R` writes it; `00_config.R:47` falls back to toy data silently.
- After `Rscript R/10_run_ranking.R`: **78 of 79 tests pass** (the failure is hard-coded FALSE at `src/tests/run_tests.R:108`, "agreement test pending"); **17 of 17 rows pass**; `payload.json` rebuilds byte-identical.

## Scores by judging stage
| Stage | Stage judge | Hostile judge | Median | Main reason |
|---|---|---|---|---|
| Understand | 2 | 2 | **2** | Sponsor notes are real, but no before/after/quote row in field notes; no outside person has used the tool; "payoff vs work" (the sponsors' key tradeoff) is off (weights 0) and award size is never shown |
| Frame | 3 | 3 | **3** | Clear problem; bar fixed before results. Two success tests still circulate (70% pool vs 50% award history); criteria rows sourced "[from notes; confirm with Kent]" |
| Solve | 3 | 2 | **2.5** | Real pipeline to a 32-agency payload, deterministic. Azure is a viewer: daily job is an echo stub, Azure OpenAI unused, top 10s contain obvious junk |
| Evaluate | 3 | 2 | **2.5** | Bar set at 1:17 am before any ranking (good). It fails, a deadline sort beats the tool in all 9 rows, the denominator flatters the tool, and nothing reaches the fact sheet |
| Drive Impact | 2 | 1 | **1.5** | No pilot ask with cost, owner or success measure; no slide brief; Q&A sheet blank |

## The one headline the team must own
**The backtest fails its own pre-set bar, and a soonest-deadline sort beats the tool.** 4-week windows: DPI 2 of 3 (67%), DEQ 3 of 7 (43%), DHHS 4 of 11 (36%); bar was 50% in 2 of 3 agencies, so 1 of 3 passes. Deadline baseline: 100%, 71%, 73%. Intervals run roughly 7% to 99%, so no better-or-worse claim is possible either way (`data/processed/backtest_result.csv`; reproduced on current rankings by reviewer 09). On top of that, the denominator only counts won programs already in the tool's own top 50, and both baselines are re-sorts of that same top 50 (`src/R/20_backtest_awards.R:79-82, 96-107`, manager confirmed). Every judge-facing reviewer (08, 09, 15, 16, 19, 20, 27, 28, 31) found this. Hiding it loses Evaluate; stating it plainly with the tradeoff is the best Evaluate answer available.

## Ranked fix list (severity x judge visibility x hours left)
| # | Fix | Why (verified evidence) | Sources | Owner (`saturday/03_contract.md`) | Proposal |
|---|---|---|---|---|---|
| 1 | Put the backtest verdict, counts, intervals and both baselines in `facts.csv` + `fact_sheet.md`, with one honest sentence; fix or relabel the denominator (add "won programs with any notice in window") | Headline evidence has no fact row, so by team rule it cannot be said on stage. Reviewer 09 estimates true denominators 8 / 15 / 32 | 09, 11, 15, 19, 20, 31 | Everett (20_*), Kent (fact sheet) | fix now |
| 2 | Show notice rows or stop them taking Top-10 slots | 61 of 320 Top-10 slots are Federal Register notices; `matchmaker.html:131` shows only `posted`, so Commerce, OAH, OSC see 2 rows; DEQ rank 9 silently missing | 10, 21, 25, 29 | Kent (11_build_payload) or Marco (tool) | fix now |
| 3 | Write the pilot ask: duration, agencies, monthly cost (computed), named owner role, success measure and stop date; fill Q&A "What should the director do Monday?" | No file holds a fundable ask (`planning/09_tool_plan_update.md:80-87` is a to-do list); every Impact reviewer and persona said "could not state next step" | 16, 19, 25, 27, 28, 29, 32 | Kent, with Marco for cost | fix now |
| 4 | Clean the obvious false positives: decode HTML entities before the geography match; add a raw-fit floor (Top 10 may be shorter than 10); drop items whose close date is before `data_as_of`; hide tribal-only and non-profit-only items | Verified: AFPRA-20-04 (Cape Verde embassy, non-profits only) is rank 1 for State Auditor; FA875025S7001 (Air Force research) rank 1 for Revenue; Hawai'i CESU (G27AS00073) escapes the geo penalty via `&#699;`; 11 tribal programs in Top 10 as "ask"; 10 Top-10 rows closed Nov 6 show "0 days left" | 08, 17, 20, 21, 22, 23, 30 | Kent (helpers_rank, 00_config) | fix now; a judge will click one agency |
| 5 | Render on screen what the payload already has: `elig_quote` for "No" and hidden rows, `award_ceiling`, cost share, `map_note`, and a source label on goal snippets ("DPI plan, Pillar 2") | DARRP hide for DEQ is correct and carries the exact exclusion quote, but the screen shows only "No". `award_ceiling` appears 0 times in `matchmaker.html` | 14, 22, 23, 25, 26, 30 | Marco (src/tool) | fix now; small |
| 6 | Rewrite `README.md` to the real run order (`10_run_ranking.R` before tests) and make `00_config.R` fail loudly instead of using toy data; move `data/example/` to `stale/` | Fresh clone crashes following README; README still says hello page / toy data | 10, 12, 18, 33 | Marco (README), Kent (config) | fix now |
| 7 | Update the field notes to Saturday: one before/after/sponsor-quote row per plan change, the failed label gate (kappa 0.44 on 3 items), DERA as "keyword missed it, a hand map fixed it", the 50% bar | Draft says "no scoring, no ranking" and the 70% pool bar; would be submitted wrong | 09, 11, 12, 14, 15, 28 | Noah (drafts), Kent | fix by 7 pm |
| 8 | Run the 2:00 pm mentor timed task on the live URL, log it in `saturday/mentor_log.md`, ship one change from it | Only route to a real "user shaped the build" row; log is empty | 14, 19, 31 | Matthew | at 2:00 |
| 9 | Judges' snapshot script (decision 10) written and tested now: no `.git`, no `api_keys.env`, no `tasks/everett_api_keys.md`, `notes/vault/`, `stale/`, eval answer key, organizer emails; scan output for both key values, `sig=`, `AccountKey`. Add `api_keys.env` to `.gitignore` | Keys are in pushed history (`78d3d2b`, on origin/main); no script exists. Manager confirmed transcripts contain no key values | 12, 13, 32, 33 | Marco; Kent signs off (rotation is Kent's call) | fix by 7 pm |
| 10 | Days-left honesty: compute days left in the browser from `close_date`, set `REF_DATE` and `data_as_of` from the build time, show "data as of" | `REF_DATE` fixed at 2026-11-06 (`00_config.R:23`); `data_as_of` is a fixed string; demo on Sunday shows 2-day-stale counts | 10, 17, 29, 30 | Kent (config), Marco (tool) | fix now |
| 11 | Coming-up panel: drop or badge forecasts whose date has passed and those marked "No" | 173 of 477 forecast rows say "date listed has passed" (manager confirmed) | 22, 23, 24, 29 | Kent or Marco | fix |
| 12 | Blob SAS expires about Nov 10: extend it or bundle a fallback payload in the image so the link still works for judges | `app/app.R` returns 502 without Blob | 08, 13, 29, 32, 33 | Marco | fix by 7 pm |
| 13 | Decide on Azure OpenAI: either one shipped advisory call (quoted one-line reason for top 10, checked by the quote script) or drop "AI-assisted" from the pitch and say keyword fit | Created, never called (`azure_setup.md`); data-use terms unread [uncertain] | 08, 19, 31, 32 | Marco + Kent decide | decide now |
| 14 | Delete or fix the dead R/JS duplicate (`ranker.js`, `ui.js`, `build_tool.R` on the old `items` shape) and the hard-coded red test | Suite can never print all-pass; `ranker.js` scores missing as 0, against `score.R` | 10, 21, 33 | Marco / Kent | defer unless cheap |
| 15 | Doc consistency sweep: building stops 6:00 pm not 7 to 8; superseded 70% bar marked in planning/08 and 02; `testing/context.md` refreshed (every reviewer reads it); mentor question F2 "8 to 38" is wrong (3 to 11); stale 1,472 / 723 counts | Verified 6:00 in `00_timeline.md:23` and F2 text | 11, 18 | Kent (context.md approval), each file owner | fix after code |

Smaller items (defer or fold in): `read_any` guesses `map_note` as logical and drops the DERA rows on read (`guess_max`), `plan_thin` null for all 32, counts line uses sample rows (DHHS shows 5 hidden of 98), `AI_USAGE_LOG.md` blank row breaks the table, SBIR/STTR items should be "No" for state agencies, `text_eligibility` "not" has no word boundary (latent), test harness `in_top_n` ranks all agencies pooled.

## Findings the manager rejected or downgraded
- "Revere Public School Educators is a misextracted goal" (08, 24, 28): **rejected.** It is DPI's real Pillar 2 (`data/processed/agency_plan_text/all/department_of_public_schools.txt:599`). Three readers misread it, so fix #5 (label the source) instead.
- "STUB DATA banner on matchmaker.html" (19): **rejected.** The banner is `hidden` unless the payload is a stub; the real payload is not.
- "Pursue/Pass button not built" (15): **rejected.** Built at `matchmaker.html:85-93`, browser localStorage only. The valid point stands: it is a decision log, not a feedback loop.
- "DARRP wrongly hidden" (23): **rejected.** Correctly hidden with the exclusion quote; the screen just doesn't show it (fix #5).
- "32 posted items with negative days left ranked" (21): **downgraded.** One item repeated across 32 agencies in `items.csv`; never reaches the payload.
- "`tasks/everett_api_keys.md` is a key file" (12): **downgraded.** No key-like strings in it; still leave it out of the snapshot.
- "backtest_result.csv is stale after the DERA map" (11, 31): **resolved.** Reviewer 09 recomputed all 9 rows on the current rankings and they match.

## Not assessed by anyone
The live Azure URL and what it serves today, live Blob contents, browser rendering, key validity, repo visibility, the submission form's format, any real user's reaction.

## Process notes for the next run
- `tests/run_tests.R` rebuilds `payload.json`; reviewers must not run it in parallel. The `/full-review` command now has the manager run it once and quote it.
- The manager briefly ran 4 reviewers at once (over the CLAUDE.md cap of 3) for a few minutes; no shared files were written.
- Recommendation from reviewer 13, not applied (Kent owns config): add `Read(**/api_keys.env)` to the deny list in `.claude/settings.json`.

# Slide brief (v2, Noah's Claude, Sat Nov 7 ~4:30 pm; replaces Kent's v1 draft)

Built from Noah's answers to 24 scoping questions and the printed judging rubric (`docs/JUDGING_RUBRIC.md`). The build plan, owners and open items are in `deliverables/slide_plan.md`. **Kent: confirm every line marked [confirm] before the deck is built.**

## Constraints
- Talk: **6:00 including a live demo, then 2:00 Q&A** (confirmed). In person, Sun Nov 8, 10:26 to 10:34 am. Aim to finish at 5:45.
- Five speakers, one per judging criterion (see timing table). Each handoff is one sentence, no "now I'll pass to...".
- Audience: judges, OSBM sponsors and agency staff. **Sponsors and end users are the authority on Understand, Frame and Drive Impact (3 of 5 criteria)**, so plain language first and technology second.
- Deck builder: Noah's Claude builds the .pptx in a **custom clean design**, keeping the organizer template's order (title, solution design, architecture/demo, pilot and scaling, Q&A, backup).
- Numbers: only from `src/docs/fact_sheet.md`, cited by row. Rows are still "Kent to confirm"; they may be used, and the checklist at the end lists each one for Kent. Anything missing reads **NEEDED** on the slide. Never round differently or add figures.
- Words: "would not have flagged", never "missed", for backtest results. Discovery content is "sponsors told us", never a quote. Simulated personas and mentor remarks are never "users said".

## Problem in one sentence
An agency grant lead in NC state government, often not a grants specialist and short on time, cannot read every open federal opportunity. grantHub (our Federal Funds Matchmaker) ranks them against that agency's own strategic plan, shows the plan goal each one matches, flags the deadline and hides what the agency cannot apply for. A person makes the final decision.

## Timing (one speaker per criterion; Starter Kit time map)
| Clock | Criterion | Slides | Speaker [confirm] |
|---|---|---|---|
| 0:00 to 0:45 | Understand | 1, 2 | Matthew (ran discovery checks and mentor slots) |
| 0:45 to 1:15 | Frame | 3 | Noah |
| 1:15 to 3:30 | Solve (live demo) | 4, 5, 6 | Marco drives and narrates |
| 3:30 to 4:45 | Evaluate | 7, 8 | Everett (owns the backtest) |
| 4:45 to 6:00 | Drive Impact | 9, 10 | Kent (states the ask) |
| Q&A | all | 11 to 15 backup | Whoever owns the criterion asked about |

## Slides

### Slide 1: Title (on screen while Speaker 1 starts; no time of its own)
- **On the slide:** "grantHub: the right federal grants to the right NC agency, in time to apply." Team Wasian: Kent, Marco, Everett, Noah, Matthew. Solve-a-thon 2026, Nov 8, 2026. Live product URL (NEEDED: final Azure URL, Marco).

### Slide 2: Who we built it for (Understand, 0:00 to 0:45)
- **Message:** We built for the agency grant lead, and for the people who would fund, approve and keep it running.
- **On the slide (user canvas, four boxes):**
  - **User:** agency grant lead. Some agencies have one person who scans Grants.gov constantly; others have nobody in charge, so everyone scans a little. Many are not grant experts.
  - **Their goal:** find the few federal opportunities worth applying for, early enough to apply.
  - **Context:** no time, short deadlines, unclear eligibility, unclear which agency should apply. A past fix (agency contacts plus a periodic survey) did not work.
  - **Around them:** funds it: OSBM (pilot budget). Approves applications: agency leadership. Keeps it running: OSBM sponsors with state IT hosting, **our proposal, not agreed** [confirm].
- **Hook (speaker only):** "Sponsors told us deadlines get missed because nobody is assigned to watch, for example a school bus program." [from notes; unverified] No dollar figure, date or "NC missed" claim unless Matthew verifies it from a primary source and Kent adds a fact row (Kent, Sat Nov 7). Note: Matthew's check (`data/manual/sat_checks.csv`) found DERA's current window is about four months and that school bus replacement is a separate EPA program, so do not say the bus window was one month.
- **Source:** `planning/07_discovery_findings.md` (our notes, not quotes).
- **Figure:** none; the canvas is the visual.

### Slide 3: What we heard, what we changed (Frame, 0:45 to 1:15)
- **Message:** Every main design choice traces to something sponsors told us, and we wrote down what we left out.
- **On the slide (heard → changed table; figure `outs/figures/heard_changed.png`, NEEDED):**
  | Sponsors told us | So we built |
  |---|---|
  | Users don't know eligibility rules | The tool sorts eligibility: 5,394 agency-opportunity pairs hidden (clearly not eligible, run by a U.S. embassy abroad, or a tribal-only program), 16,288 shown with "check eligibility" (rows 7, 8) |
  | No time; more questions is bad | One required question (pick your agency). Everything else optional |
  | A deadline was missed because nobody noticed | Days-to-deadline on every row and a closing-soon list |
  | Nobody knows which agency should apply | All 32 agencies ranked (row 2), plus a view across agencies |
- **Left out on purpose (one line):** writing proposals, private foundations, a setup quiz, past awards in the score, AI labels in the ranking.
- **Reframe line (rubric Frame 4, "reframed the problem as they learned"):** "We started with 'rank grants by plan fit for one agency.' Sponsors changed it twice: screen out what you can't apply for before ranking, and serve all 32 agencies, not one."
- **Ranked requirements (backup or a side panel; full version with "where met" in `FIELD_NOTES.md` 1.3).** D# = numbered requirement in `planning/07_discovery_findings.md` (our notes, not quotes):
  | Rank | Requirement | From sponsors | Status |
  |---|---|---|---|
  | 1 | Save time, never add work | D1 | Met: one required question |
  | 2 | Fast and simple | D2 | Met |
  | 3 | Tool sorts eligibility | D3 | Met (rows 7, 8) |
  | 4 | Deadline on every row | School-bus example, D10 | Met |
  | 5 | Cross-agency | D5 | Met: 32 agencies (row 2) |
  | 6 | Public data, privacy | D6, D7 | Met |
  | 7 | Explain every match, human decides | D10, organizers | Met |
  | 8 | Payoff versus effort | D4 | Partly: shown and sortable, weights 0 by design |
  | 9 | Beyond Grants.gov | D8 | Partly: 4 more sources; SAM postings, DOT, foundations not loaded |
  | 10 | Draft the proposal | D9 | Left out on purpose |
- **Scope held (one line, speaker only):** "We fixed a must-have for Saturday 1 pm, live on Azure, and wrote a cut order for everything else. When our AI labels failed a blind check, we kept them out."
- **Speaker note:** Say requirements in priority order: save time, simple, eligibility, deadline, cross-agency, public data only. "Payoff versus effort" (award size, burden): say it before they ask. "Rank is plan fit only, by design, so a big award never outranks a real fit. Award size, cost share and time left are shown on every row and sortable (Sort: best payoff, biggest money); turning their weights on is a pilot setting." Check: `data/manual/criteria.csv` gives `award_size`, `no_cost_share` and `runway` weight 0.

### Slide 4: How it works (Solve, 1:15 to 1:35)
- **Message:** Three plain steps, and a person decides.
- **On the slide:** (1) Read each agency's strategic plan and every open federal notice. (2) Score how well each notice matches the plan, remove what the agency cannot apply for, and lower notices aimed at another state. (3) Show the matching plan goal with its exact words, the deadline and a Pursue / Maybe / Pass choice.
- **Numbers:** 1,576 open opportunities (row 3), 32 agencies (row 2), 153 plan goals (row 19).
- **Figure:** `outs/figures/process_3step.png` (NEEDED).
- **Speaker note:** The AI only reads and labels text with a quote; it never ranks or hides anything.

### Slide 5: Live demo (Solve, 1:35 to 3:10)
- **Message:** It runs on Azure, for any of the 32 agencies. **Say this only if the Sunday-morning check passes:** the live URL shows "Start swiping" and the post-filter payload (`saturday/deploy_checklist_sun.md`, PR 106). As of Sat 6 pm the live page is the older version. If the deploy has not happened, demo locally and say so.
- **On the slide:** URL plus one screenshot as the fallback image (`outs/figures/demo_dpi_bus.png`, NEEDED from the live URL after the deploy).
- **Demo path (Kent, Sat Nov 7: DPI with the school bus query, not DEQ).** Draft from Marco's handoff; time it on the live URL after the UI PR merges and the deploy, and keep the total at 1:35 or less [timing NEEDED].
  1. Open the live URL with `?agency=dpi` (Azure URL visible in the address bar). One line: "Department of Public Schools, picked."
  2. Type in "Tell us your situation": `clean diesel school buses, I have 4 weeks`, press Apply. DERA (Diesel Emissions Reduction Act) comes first.
  3. Open "Why it fits, odds and details" on DERA: the plan goal it matched and the words behind it. Say the odds and effort chips are team rules, not measured.
  4. Start swiping; swipe right on DERA (adds to the cart).
  5. Open the plan: timeline worked back from the deadline and the checklist.
  6. Open the cart; tick two grants and Compare.
  - Do not browse DPI's unfiltered Top 10 on stage (its #1 is a Tribal Colleges program; see `testing/transcripts/35_hostile_judge_pitch_20261107.md`). The query keeps the demo on DERA.
  - Still to show if time allows: the hidden count (row 7) and a person choosing Pursue / Maybe / Pass.
- **Backup:** screen recording of the same path, 90 seconds (NEEDED, Marco). Set min replicas to 1 before 8:30 am to avoid the 38-second cold start.
- **Speaker note:** Say that the DERA link to DPI and DEQ comes from a hand-made program link we still need to confirm (row 14 is marked uncertain).

### Slide 6: Architecture (Solve, 3:10 to 3:30)
- **Message:** A small, cheap setup the state can run and hand over.
- **On the slide:** diagram from feeds (Grants.gov, Simpler.Grants.gov, Federal Register, SAM.gov listings) and the 34 OSBM plans, through the R pipeline, then `payload.json`, then the Azure Container App, then the browser. Mark what is live versus planned (daily job, Blob, Azure OpenAI).
- **Figure:** `outs/figures/architecture.png` (NEEDED; organizer architecture skill, then checked line by line against what is actually deployed).
- **Messy data handled (one line):** 488 with no usable close date and 887 with no usable award ceiling are kept and labeled, not dropped (rows 5, 6). (Rubric Solve 4.)

### Slide 7: Does it work? (Evaluate, 3:30 to 4:30)
- **Message:** We tested it against grants agencies actually won, set the bar first, and it did not pass. Here is what that tells us.
- **On the slide:**
  - "Bar set before the test: at least 50% of an agency's won programs in its Top 10, in 2 of 3 agencies."
  - Result, 4-week windows: DPI 2 of 3, DEQ 3 of 7, DHHS 4 of 11. **1 of 3 agencies met the bar** (row 15). Say it this way. If asked: after three later ranking fixes (embassy filter, region list, tribal-title rule) the rerun reaches 2 of 3 (DPI 2 of 4, DEQ 4 of 7, DHHS 4 of 10); we report the pre-set result because the fixes came after we saw it.
  - "A plain sort by soonest deadline did at least as well in all 3" (row 16).
  - "Our AI labels failed a blind check, so none are used in the ranking." (`drafts/claude/docs/holdout/label_check_result.md`; no number on the slide.)
- **Figure:** `outs/figures/backtest_recall.png` (exists).
- **Optional line (exploratory, rows 7 and 26) [Kent to confirm]:** "A Claude review of our own output caught overseas U.S. Embassy grants in state agencies' lists. That was our keyword ranking, not the AI labels. One filter rule removed them. A second review, playing a hostile judge, found a Gulf Coast-only grant (RESTORE Act) at DEQ #3 and Tribal Colleges (TCUP) at DPI #1; a wider region list and a tribal-only eligibility rule fixed both, each quoting the title. After the fixes, reach rose to 61 of 157 won programs (rows 7, 26)." Also fits backup slide 13 and the field notes' "AI was wrong" table.
- **Speaker note:** Use `src/docs/backtest_framing.md`. Why it still helps: the test rewards repeat funding, not new fits, and the samples are small (3 to 11 programs). The tool does what a deadline sort cannot: removes ineligible items, shows the plan goal, flags other-state items. The 50% bar is a team judgment. We did not move it after seeing the result.

### Slide 8: Weakness and tradeoff (Evaluate, 4:30 to 4:45)
- **Message:** Our main weakness is that word matching misses real fits that use different words.
- **On the slide:** Tradeoff: word matching is transparent (every match shows the words behind it) but misses synonyms. Fix: meaning-based matching on Azure, untested. In the pilot: grant leads keep their manual checks so we can measure what the tool misses.

### Slide 9: The ask: a 60-day pilot (Drive Impact, 4:45 to 5:35)
- **Message:** Fund a 60-day pilot with three agencies; this is what it replaces and how you will know it worked.
- **On the slide:**
  - **Who:** grant leads at DEQ, DPI and DHHS [confirm agencies], one each. OSBM owns it (our proposal).
  - **Replaces:** each agency scanning Grants.gov alone, and the contact-and-survey approach that did not work.
  - **Measure built in:** grant leads mark Pursue / Maybe / Pass and keep their usual manual checks; each week we report what the tool caught, what it would not have flagged, and what was pursued. Each mark already goes to the team's log (no personal data) and `app/pilot_scorecard.sh` turns it into the weekly hit rate; using the marks to retune the ranking is pilot work (say so).
  - **Cost:** NEEDED: measured Azure cost from Marco, added to the fact sheet first.
  - **Why now:** 71 Top 10 items close within 14 days, across 24 agencies (rows 17, 18).
- **Speaker note:** One sentence: "We are asking for a yes on a 60-day pilot, an OSBM owner, and three grant leads."

### Slide 10: Roadmap and risks (Drive Impact, 5:35 to 6:00)
- **Message:** Three realistic steps, each with its main risk.
- **On the slide:**
  1. **Pilot (60 days):** three agencies, weekly catch report. Risk: grant leads stop doing manual checks, so we lose the comparison.
  2. **Better matching plus saved feedback:** meaning-based matching on Azure OpenAI; Pursue / Maybe / Pass saved centrally to tune weights. Risk: the matching has not been tested yet and may not beat word matching.
  3. **Statewide and more sources:** all 32 agencies, daily alerts, more sources (agency sites like DOT, foundations). Risk: stale or vague agency plans weaken matches (the count of plans that ended before 2026 is not a fact row: add one or say "some plans").
- **Close (last line spoken):** "Would you fund a pilot? A yes means 60 days, three agencies, one owner at OSBM."

### Slides 11 to 15: Q&A backup (not presented)
11. Data sources and coverage (what is pulled, what is not: SAM catalog via bulk file, DOT page blocked).
12. Eligibility rules with one hidden example and its quote.
13. AI use: where the AI was wrong and how we caught it (label check; goal-heading fit that failed on real data; 2019-date stub; embassy notices, below).
14. Stakeholders in more detail (optional stakeholder map).
15. Cost and security: public data only, keys not in the judge repo, Azure spend.

## Style (custom design)
- Clean, high contrast, one idea per slide, large type (headline 36pt or more, body 24pt or more).
- One accent color and neutral grays; check that charts read the same with the `dataviz` skill palette. Direct labels, no legends.
- No em dashes, no stock photos, no clip art. Footer: "Solve-a-thon 2026 · Team Wasian".

## Checks before submitting (Kent ticks)
- [ ] Fact rows used: 2, 3, 5, 6, 7, 8, 14, 15, 16, 17, 18, 19. Each confirmed by Kent.
- [ ] No NEEDED left on any slide (school bus figure, cost, URL, demo path, figures).
- [ ] Demo path timed at 1:35 or less, with the recording ready.
- [ ] Read aloud with all five speakers at 5:45 or less.
- [ ] Every "live on Azure" claim checked on the URL Sunday morning.

_The stale v1 slide block (old "Slide 1: The ask" to "Slide 6: Next step", pre-filter numbers) moved to `_team/archive/stale/slide_brief_v1_block_20261107.md` on Sat Nov 7 (Kent). Build only from the v2 slides above._

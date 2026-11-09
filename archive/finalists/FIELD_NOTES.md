# Solution Design and GenAI Field Notes: grantHub (Federal Funds Matchmaker)

Solve-A-Thon 2026 Final Quest, sponsor NC Office of State Budget and Management (OSBM).
Team: Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin, Noah Goldblatt.
Live tool on Azure: https://ffm-app.bluepebble-2cbaa7af.eastus.azurecontainerapps.io/

How to read this. Every number comes from [src/docs/fact_sheet.md](src/docs/fact_sheet.md) (row number in brackets) and is re-derived by `src/R/check_facts.R` (49 of 49 rows pass). Discovery points are from our merged notes of the Fri Nov 6 session ([planning/07_discovery_findings.md](planning/07_discovery_findings.md), [notes/vault/Solveathon_DiscoverySession.md](notes/vault/Solveathon_DiscoverySession.md)). They are paraphrases, not quotes, and state staff names are left out on purpose. Where something was not measured, we say so. The full working draft, with every decision and its source, is [drafts/claude/docs/field_notes_draft.md](drafts/claude/docs/field_notes_draft.md).

---

## Part 1. End user and solution design

### 1.1 Who we built it for

**Primary user: an agency grant coordinator.** This is whoever at an NC state agency decides which federal opportunities are worth a closer look. What we learned at discovery:
- Capacity varies widely. One agency in the room had a person who writes grants and screens Grants.gov constantly. Another had nobody in charge of scanning, so each person scans a little.
- No "grant explorer" role exists. Most agencies have no dedicated grants staff.
- Many users are not grant experts. The tool has to work for the average person who does not normally do grants.

**Sponsor and second user: OSBM.** OSBM wants the same view across agencies. We heard there is no dedicated OSBM team for this and that it would likely run as a cross-agency partnership.

**What they do today.** People scan Grants.gov by hand and rely on mailing lists, other agencies' notices and word of mouth. OSBM once tried asking each agency's point of contact and running a periodic survey. It did not work. Nobody knows how many opportunities are missed.

**The worked example the sponsors gave.** NC missed the first-year deadline of a school-bus funding round because nobody noticed it in time. Our demo uses the EPA Diesel Emissions Reduction Act (DERA) notice (opp 363936, Assistance Listing 66.039). It ranks #1 for DEQ and #3 for DPI [row 14]. The link between that program and those agencies is marked uncertain in the fact sheet.

**The decision the tool supports.** Which open or forecast federal opportunities this agency should look at first, early enough to apply. A person decides. The tool orders, filters and explains. It never applies, and it never makes the final call.

### 1.2 What we heard, and what it changed

| Our plan before discovery | What sponsors told us | What we changed |
|---|---|---|
| Rank opportunities by fit to the agency's strategic plan | Agencies skip grants without a real payoff, and payoff versus work is the key tradeoff | Award size, cost share and time to apply are columns on every row, with weights the user can adjust. **Honest note:** the default rank is plan fit only. The payoff and effort weights are 0 in [data/manual/criteria.csv](data/manual/criteria.csv) until users set them |
| Eligibility as one part of the score | The tool, not the person, must sort eligibility, because users may not know the criteria | Eligibility became a filter with a reason. Clearly ineligible items are hidden, with a count and an example. Unclear items stay visible with an "Ask" badge and the quote. Text can rule an item out but never confirm it [rows 7, 8] |
| Deadline as one input among many | Short deadlines caused the school-bus miss, so time is the constraint | Days left and a "closing soon" flag on every row. Deadline alerts in the tool. A "Coming up" list for forecasts. 71 Top 10 rows close within 14 days, across 24 agencies [rows 17, 18] |
| Onboarding: the user ranks 10 sample grants before seeing results | Do not ask busy users more questions; waiting minutes fails | The onboarding was cut. Feedback is optional and comes after results: Pursue / Maybe / Pass on each row, plus a feedback form |
| Grants.gov only | Grants.gov alone is not comprehensive | We added Simpler.Grants.gov, Federal Register notices, USAspending award history and the SAM.gov Assistance Listings catalog (statutory authority, program spending). SAM.gov postings and the USDOT page are **not** loaded (rate limit; the site returns 403 to scripts) |
| Serve one agency, as the Starter Kit suggested | Cross-agency by design | All 32 agencies with plans [row 2], in one tool with an agency picker |
| Privacy not considered | Do not send sensitive information to an arbitrary model | Only public text (notices and plans) goes to a model. The model runs in our own Azure OpenAI resource |
| Proposal drafting not considered | A tool that also drafts the proposal would be top tier | Not built. Each row shows a short requirements summary and a Shipley-style color-team timeline as a starting point |

### 1.3 Problem statement and key requirements

**Problem.** Agency grant coordinators find fitting federal opportunities late or not at all, because monitoring is manual, fragmented and uneven across agencies. The smallest agencies miss the most.

**How the problem changed as we learned.** We first framed it as "rank grants by fit to the agency plan, for one agency." Discovery changed it twice: (1) screen out what the agency cannot apply for *before* ranking, and show payoff and effort on every row, because users don't know the eligibility rules and skip grants without a real payoff; (2) serve all 32 agencies, not one, because the need is cross-agency and OSBM has no team for it. A data check changed the named case: Clean School Bus (66.045) has 0 rows in our data, so DERA (66.039) became the example [row 14].

**Requirements in priority order, traced to sponsor input.** "D#" is the numbered requirement in [planning/07_discovery_findings.md](planning/07_discovery_findings.md) (our merged notes of the Fri Nov 6 discovery session; paraphrases, not quotes). The order is the team's ranking: anything that adds work for the user loses to anything that saves it.

| Rank | Requirement | Traced to | Where it is met | Status |
|---|---|---|---|---|
| 1 | Save time; never add work | Sponsors, D1 (time is the constraint; more questions is bad) | The page opens to an agency's Top 10. The only required question is the agency. The 10-grant onboarding quiz was cut | Met |
| 2 | Fast and simple | Sponsors, D2 ("easy, quick, likely successful"; waiting minutes fails) | One static page reading one file (`payload.json`); no waiting on a model | Met |
| 3 | The tool sorts eligibility, not the person | Sponsors, D3 | Eligibility filter with a quoted reason; clearly ineligible items hidden with a count; unclear items stay with an "Ask" badge ([src/R/helpers_rank.R](src/R/helpers_rank.R) `assign_eligibility()`) [rows 7, 8] | Met |
| 4 | Deadline and time to act on every row | Sponsors' worked example (a school-bus deadline missed because nobody noticed); D10 (time stated throughout) | Days left, a closing-soon flag, deadline alerts, a "Coming up" list for forecasts [rows 17, 18] | Met |
| 5 | Cross-agency by design | Sponsors, D5 (no OSBM team; likely a cross-agency partnership) | All 32 agencies in one tool with an agency picker and a match board across agencies [row 2] | Met |
| 6 | Public data only; protect privacy | Sponsors, D6 and D7; organizers | Public sources only; only public text (notices, plans) goes to the model, which runs in our own Azure OpenAI resource | Met |
| 7 | Explain every match; a human decides | Organizers; D10 (explain simply) | Matched plan goal in the plan's own words, a one-line "why", Pursue / Maybe / Pass. The model only summarizes, with a quote checked against the source | Met |
| 8 | Payoff versus effort, not fit alone | Sponsors, D4 | Award, cost share and runway shown and sortable on every row, plus signature tier. **Their ranking weights are 0 by design** in [data/manual/criteria.csv](data/manual/criteria.csv), so a big award never outranks a real fit; turning them on is a pilot setting | Partly met |
| 9 | Look beyond Grants.gov | Sponsors, D8 ("not comprehensive") | Added Simpler.Grants.gov, Federal Register, USAspending awards and the SAM.gov Assistance Listings catalog. SAM.gov postings, the DOT page and private foundations are not loaded | Partly met |
| 10 | Draft the proposal | Sponsors, D9 ("top tier") | Not built. Each row has a short requirements summary and a color-team timeline as a starting point | Left out on purpose |
| Must | Runs on Azure | Organizers (hard requirement) | Container Apps, Blob Storage, Container Registry, Azure OpenAI (see 1.4). The daily refresh job runs in dry-run mode (see Part 3) | Met, refresh not live |
| Must | Address false positives, false negatives, uneven documentation and data quality | Organizers (named threats) | See Part 3 | Addressed |

**Left out on purpose, and why.** Proposal drafting (too large for the weekend, and a person should own the application). Private foundations (no public feed we could load). The onboarding quiz (sponsors said no extra questions). Past awards in the score (it would favor repeat winners; award history is shown, never scored). AI relevance labels in the ranking (they failed a blind held-out check; see 2.3).

**Scope held under pressure.** The must-have was fixed at Saturday 1:00 pm: the agency picker and a keyword Top 10 live on Azure, plus the award backtest number. Everything else had a written cut order ([saturday/02_decisions.md](saturday/02_decisions.md), decisions 1, 11 and 12). When the model labels failed validation, we kept them out of the product instead of shipping them.

### 1.4 How it works

1. **Load.** R scripts pull opportunities from Grants.gov, Simpler.Grants.gov and the Federal Register. They also load USAspending awards and the SAM.gov listings file. Every response is cached in `data/cache/`, so a rerun is free and repeatable. Result: 1,576 open opportunities [row 3].
2. **Build agency profiles.** We downloaded 34 strategic plans from OSBM [row 1] and extracted the text, with OCR for image-only pages. Goals were recorded with quotes that a test checks against the source page. After merging duplicates, 32 agencies remain [row 2], carrying 153 plan goals [row 19].
3. **Filter, score, rank.** Each opportunity is scored against each agency's plan: 50,432 pairs [row 4]. The filters hide 5,394 pairs that are clearly ineligible, run by a U.S. embassy abroad, or limited to tribal programs [row 7]. The fit score is keyword overlap with the plan text. A title naming another state or region halves the fit [row 13]. Every rule is one row in `criteria.csv`, and every threshold is in `src/R/00_config.R`.
4. **Summarize.** Azure OpenAI `gpt-4o-mini` writes a two-sentence plain summary of each notice, plus one exact quote. A summary is kept only if its quote is found in the notice text (`src/R/31_swipe_summary.R`).
5. **Show.** A one-page tool, grantHub (`src/tool/matchmaker.html`), reads one file, `payload.json`. It shows the Top 10, Coming up and Hidden lists, deadline alerts, a county map, a match board of plan goals, Pursue / Maybe / Skip marks, CSV export and a feedback form. Each grant can also say **who it reaches**: a population group (children, veterans, older adults and others) from keyword rules on the announcement, with the matching quote, and where that group lives in NC (top counties, rural or urban, congressional districts, a map layer). The population data is reused from our qualifier work (ACS 2023). It is display only and never enters the rank.
6. **Host.** Azure Container Apps serves the page. `payload.json` comes from Blob Storage, with a baked-in fallback copy. A daily refresh job (`app/job.R`) runs in Azure in dry-run mode (see Part 3). **What is not automated yet:** fetching new postings from Grants.gov is a manual step, and the job cannot write a new payload until it has a storage write role. Both are pilot step 1.

### 1.5 Main design decisions and tradeoffs

| Decision | Why | What we gave up |
|---|---|---|
| Rules and keyword fit, not a model, decide rank and eligibility | Transparent, reproducible, cheap; a judge or coordinator can read every rule | Keyword fit misses grants that use different words and makes some odd matches |
| The LLM only summarizes, with a checked quote | Sponsors' privacy concern and the "human decides" rule | No model-based relevance; our local-model labels failed validation and are not used (see 2.3) |
| All 32 agencies, not one | Matches the cross-agency need | Breadth over depth; the evaluation covers 12 to 18 agencies, not all |
| Unknown stays visible ("Ask"), never silently dropped | A wrong eligibility code must not hide a real opportunity | Longer lists to scan |
| Award history shown, never scored | Avoids rewarding only repeat winners | The tool cannot yet learn from past wins |
| Marks saved in the browser, and each mark logged without personal data | No accounts needed, and the team can still measure use | A team cannot yet share one list; marks do not yet change the ranking |
| Static page plus one JSON file | Fast load, easy to host, no database to secure | Refreshing data means rebuilding the file |

### 1.6 What we tested with people, and what we did not

- **Discovery session (Fri Nov 6):** agency and OSBM staff. This shaped every row of table 1.2.
- **Tool testing (Sat Nov 7):** a round of fixes was logged as coming from user testing: tour flow, wrong-agency jumps, "Match an idea" matching, the map, mobile swipe ([AI_USAGE_LOG.md](AI_USAGE_LOG.md), last row). The testers were other undergraduates, people working in the field (consultants and government workers), and other adults. None was agency or OSBM staff, so none of this is evidence from the real users.
- **Simulated reviewers:** 37 AI persona and judge transcripts in [testing/transcripts/](testing/transcripts/), covering grant writer, non-grants staffer, budget director, IT architect, hostile judge and others. They found real bugs, such as embassy notices and out-of-region grants in Top 10 lists. **They are not user evidence**, and we do not report their opinions as what users said.
- **Not done:** no agency coordinator has used the tool on their own work over days. That is what the pilot is for.

---

## Part 2. GenAI field notes

### 2.1 Tools used

Sources: [AI_USAGE_LOG.md](AI_USAGE_LOG.md), one row per session, with what a person checked.

| Tool and model (as logged) | Who | Used for |
|---|---|---|
| Claude Code (Claude Opus 5.5 for planning and review; Claude Sonnet 5.5 for code) | Kent, Marco, Noah, Everett | R pipeline (ingestion, ranking, eligibility, payload, backtests), the tool page, Azure setup with each create approved by Marco, drafts, reviewer and persona runs |
| Codex (GPT-6) | Noah, Matthew | Plan PDF extraction and checks; DERA eligibility and date checks |
| OpenCode (Big Pickle; DeepSeek V4.1 Flash Free; one model logged only as "Default chat model") | Matthew, Everett | Eligibility checks, persona agents, award-backtest scripts |
| Local Ollama `qwen2.5:14b` | Kent | Trial relevance labels for an evaluation pool. They failed validation and are **not** used in the tool |
| Azure OpenAI `gpt-4o-mini` (resource `ffm-aoai-team15`) | Team | **In the product:** notice summaries with a checked quote (`src/R/31_swipe_summary.R`, about 558 calls, about $0.07 as logged) and an advisory "can a state agency apply as lead?" label (`src/R/30_notice_reader.R`). Neither sets rank, eligibility or tier |

No other generative AI tool was used: no UNC PromptLab, no ChatGPT. The only tools were Claude Code, OpenCode and Codex (as logged), local Ollama, and Azure OpenAI in the product.

### 2.2 Key prompts

Full text is in the files named.

1. **Standing rules for every AI session** (in each teammate's AI instructions):
   > "Do not invent numbers, sources, quotes, names or facts. If something is missing, write 'not found' and tell me."
   > "If an LLM is used on data, it only labels with quoted evidence. It does not make the final decision."
2. **Azure setup (Marco, Claude Code):**
   > "NEVER write a key, token, connection string or password to any file, commit, or chat output."
   > "Stop and ask before: any az create or delete, any role assignment, changing an existing resource..."
3. **Plan text extraction (Noah, Matthew):**
   > "Accuracy matters more than speed. If you cannot verify something, write 'unknown'; never guess."
   > "Every goals_quote and plan_years value MUST be copied from the extracted text, not paraphrased or recalled."
4. **Notice summary (Azure OpenAI, in the product; `src/R/31_swipe_summary.R`):** a two-sentence plain summary plus one exact quote from the notice. The code throws the summary away if the quote is not found in the notice text.
5. **Lead-applicant reader (Azure OpenAI; `src/R/30_notice_reader.R`, version `n1`):**
   > "Can a North Carolina state agency apply as the lead applicant?"
   The answer is one of lead, partner, not_eligible or unclear, with a checked quote. Temperature 0, at most 60 calls per run, text cut to 6,000 characters.
6. **Evaluation labels (local model; `drafts/claude/eval/model_label.R`, `evalpool-v3`):**
   > "For 'relevant' or 'maybe', evidence must be ONE short exact quote (under 25 words) copied character for character from the Title or Summary lines."

The prompts used to write the ingestion pipeline and the framing worksheet were not saved.

### 2.3 Where the AI was wrong, and how we caught it

The full list of 18 cases is in the working draft, section 7. The clearest ones:

1. **The AI-written relevance labels failed, twice.** A local model labelled grants relevant, maybe or not relevant for an agency. It failed the gate on the validation items its prompt was written against. Then Noah and Matthew hand-labelled a blind held-out set without seeing the model's output, and it failed there too. *Caught by:* a pass/fail gate written before the run, plus blind human labels (`src/R/40_label_check.R`, `drafts/claude/docs/holdout/label_check_result.md`). *Result:* model labels are not used anywhere in the ranking.
2. **The AI named a "known-good" test case that is not in the data.** The AI-drafted framing worksheet used Clean School Bus (CFDA 66.045) as the case the tool must find, tagged uncertain. A search of our opportunity table found 0 rows with that number. *Caught by:* checking the claim against the file. *Fix:* the DERA notice (66.039) became the named case [row 14].
3. **The AI misreported its own output.** A Codex-written CSV said the Justice plan text had 20,160 characters. The saved file was 1 byte. *Caught by:* comparing the claim to the file. *Fix:* all 34 plans were re-extracted by one script (`src/R/04_plan_text_extract.R`).
4. **AI-written code silently dropped data.** The SAM.gov listings script kept only program numbers shaped `NN.NNN`, which silently dropped 210 of 2,875 rows. The AI then explained the gap with a guess ("duplicates") that turned out to be false. *Caught by:* one number that did not reconcile. *Fix:* the script now warns when it drops any row.
5. **AI reviewers were sometimes wrong too.** Three reviewer agents said a DPI plan goal was misextracted. It was correct. *Caught by:* searching the plan text. We treat every AI review finding as a claim to check, not a fact.

Related, and found by AI review rather than made by AI: our rule-based ranking put U.S. Embassy grants and Gulf Coast-only grants in NC agencies' Top 10 lists. A hostile-judge agent caught the out-of-region case, and new filter rules fixed both [rows 7, 13].

### 2.4 What people checked

Marco approved every Azure create. Kent chose every design option in the planning interview; the AI only recommended. Kent read every Top 10 eligibility "yes" row. Noah and Matthew labelled the blind held-out set. Matthew checked DERA eligibility and dates against the Grants.gov pages. Rows of the AI log that say "checked by Claude only" are not counted as verified here.

---

## Part 3. Evaluation: where it works and where it doesn't

**Test set before looking (failed).** We fixed a bar in advance: 50% of programs each agency actually won should appear in its Top 10, in 2 of 3 agencies (DPI, DEQ, DHHS), on 4-week windows. **1 of 3 met it** [row 15]. On that test, a plain soonest-deadline sort beat us in all 3 [row 16]. After three later ranking fixes (made for other reasons), a rerun meets it in 2 of 3. We report the pre-set failure.

**Wider test (exploratory, built after the first failed).** We took 157 programs that 12 agencies actually won and replayed 4-week windows over two years:
- Our Top 10 reached **61 of 157 (39%)**, and our Top 50 reached 98 (62%) [rows 26, 27].
- A soonest-deadline sort reached 19.7%, and a random 10 reached 14.1% [row 29].
- 4 of 12 agencies were at or above 50% [row 28].

**Reach, bonus quest 1 (exploratory).** A "newest posted first" list stands in for a new-postings alert. It reached 35 of the 157; we reached 61. We caught 39 that the alert missed, and the alert caught 13 that we missed [row 31]. The alert is a stand-in for manual monitoring, not a measurement of it.

**Timeliness.** With 4-week refreshes, 41 of our 61 catches still had at least 21 days left. With 2-week refreshes, 53 did [row 32]. This is the case for a daily refresh.

**Named weakness and tradeoff.** Keyword matching is transparent and cheap, but it misses grants worded differently from the plan and makes odd matches (for example, Army research and NASA programs shown to the Treasurer). A Top 10 still leaves most won programs out. We chose explainable rules over a black-box model we could not validate: our one model-labelling attempt failed its gate.

**Named threats:**
- *False positives.* Every row shows its matched goal and its reason, and a person marks Pursue / Maybe / Pass. Filters remove clearly ineligible items, and unclear items say "Ask".
- *False negatives.* The pilot keeps manual monitoring running beside the tool and counts what each catches. Recall is the headline measure.
- *Uneven agency documentation.* Match quality depends on plan wording. Four plans are older. Only DHHS and DMVA have a capability table [row 23]. A standard agency-profile template is part of the scale plan.
- *Inconsistent data quality.* 488 open items have no usable close date and 887 have no usable award ceiling [rows 5, 6]. The tool shows "not listed" and never makes up a value.

**Evaluation built into the solution.** Every Pursue / Maybe / Skip mark is sent to the app's feedback log (agency, grant, rank, mark and a random browser code; no name or email). `app/pilot_scorecard.sh` turns that log into the pilot's running measure: of the Top 10 grants people marked, the share they kept, by agency. Each user sees their own version in My grants. With manual monitoring kept running beside it, this gives both precision (how many Top 10 grants are worth keeping) and, from what manual monitoring finds that we did not show, recall. No real user has produced marks yet, so we report no hit rate.

**What the refresh job really does.** On Nov 8 at 05:02 UTC we ran the Azure job once by hand on the current image. It succeeded: it checked the payload (32 agencies), dropped 15 rows whose close date had passed, and wrote nothing because it is in dry-run mode. It did not re-score, because the app image does not carry the ranking code.

**Not verified.** The Azure daily refresh job exists but runs in dry-run mode (`JOB_DRY_RUN=1`): it re-scores cached data and does not fetch new postings. We do not claim a live daily refresh. Measured Azure spend is not in the fact sheet.

---

## Part 4. Pilot and scale (summary of the pitch)

- **Pilot:** 60 days, three agencies (proposed: DEQ, DPI, DHHS), one grant lead each, one OSBM owner. Grant leads keep their usual manual checks and mark Pursue / Maybe / Pass. Each week we report what the tool caught, what manual monitoring caught, and what was pursued.
- **Step 2:** save marks centrally and use them to tune weights (bonus quest 3). Test meaning-based matching on Azure OpenAI against the keyword baseline before adopting it.
- **Step 3:** all 32 agencies, a live daily refresh with deadline alerts, more sources (agency sites such as DOT), and a standard agency-profile template so weaker plans still get good matches.

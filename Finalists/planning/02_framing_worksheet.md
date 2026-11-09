# Framing worksheet (Fri 7:30 to 8:45 PM sprint)

Fill this in on paper or here before any data is opened. One page. Plain words. Anything the client did not say is [assumed].

## 0. Given by the organizers (not ours to change; full text in `../QUEST_BRIEF.md`)
- Build on Azure; public or provided data only; humans make the final decision.
- Must: load federal opportunity data, build agency profiles from real NC strategic plans, score and rank, summarize, simple interface.
- Must address: false positives, false negatives, uneven agency documentation, inconsistent data quality.
- Judged on Understand, Frame, Solve (cloud use), Evaluate, Drive Impact (pilot budget from OSBM).
- Still ours to decide after the workshop: which user, which decision, which agencies, the 3 to 5 criteria, the success test.

> **Status (Fri Nov 6, late):** drafted by Claude from `07_discovery_findings.md` and Kent's decisions (serve all agencies; Nov 6 night). Every line marked [assumed] is a draft for Kent to edit. Source tags [from notes] mean our organized discovery notes, not verbatim sponsor quotes.

## 1. One-sentence problem
[from notes; confirmed in the discovery session] Agency grant coordinators miss or find late federal opportunities that fit their agency, because monitoring Grants.gov or SAM.gov and judging fit against strategic plans is manual and uneven.

## 2. User card
- **Who (role, not a name):** an NC state agency grants lead or coordinator. Many agencies have no one in this role; the tool must also work for "the average person who does not normally do grants" [from notes]. One tool serves all agencies; each user sees results for their own agency. OSBM staff see all agencies (cross-agency view) [assumed].
- **Job and time available:** screens federal opportunities among other duties; little time and short deadlines [from notes]. Time available per check: [assumed, ask]: a few minutes.
- **What they do today:** scan Grants.gov by hand, rely on points of contact and a periodic survey (the crowdsourcing fix did not work) [from notes].
- **Their words for the problem:** no time, no dedicated person, short deadlines, unclear criteria, not knowing which agency should apply; nobody knows how many opportunities are missed [from notes]. School bus funding first-year deadline missed [from notes; details unverified].
- **What makes them distrust a tool:** more questions to answer, slow answers, no stated reason for a match, a recommendation that ignores eligibility [from notes, requirements 1 to 4; trust items assumed].

## 3. Decision and action
- **Decision they make:** which open or forecast federal opportunities are worth pursuing for their agency, early enough to meet the deadline [from notes].
- **Action our result should trigger (a specific next step, owner, date):** the coordinator opens the top matches, confirms eligibility and fit using the stated reason, and tells their supervisor "pursue" or "pass" before the close date. A human decides; the tool never applies or ranks anything as final [from the brief]. Owner: the agency coordinator; deadline: before the close date minus working time [assumed].

## 4. Success test
- **How the user would know it worked:** the shortlist has a few matches they would act on, each with a plain reason, and nothing they would have been embarrassed to miss [assumed].
- **How we will show it works (a test we can run):** (1) a hand-labelled pool per demo agency: recall of the labelled-relevant items in the top N, with N and the pass bar set by Kent before scoring [open]; (2) a known-bad item (clearly irrelevant, or ineligible) must rank last or be filtered with a reason; (3) a known-good case (the Clean School Bus program, CFDA 66.045 [uncertain]) must appear for the education and environment agencies; (4) the same input gives the same output on rerun. All pass/fail bars are written before looking at results.

## 5. Criteria (3 to 5; each measurable and tied to a data field)
Copy into `data/manual/criteria.csv` (columns: id, type, label, field, rule, value, weight, if_missing, why, source).

| Vague (their words) | Measurable rule | Likely data field | Source (client quote) | Filter or score |
|---|---|---|---|---|
| "Eligibility is sorted by the tool, not the person" | Applicant types include state government or unrestricted; otherwise flag with the reason. If the field is blank, flag "check eligibility", do not drop. Code meanings to verify against Grants.gov docs [uncertain] | `applicant_types`, `applicant_types_named`, `eligibility_text` | [from notes] requirement 3 | Filter (flag when missing) |
| "Short deadlines", "early enough to act" | Days left = `close_date` minus `REF_DATE`. Posted items only; forecasted items shown with an estimated date; "closing soon" flag at a threshold set in `00_config.R` | `status`, `close_date`, `is_forecast` | [from notes] requirement 1; bonus quest "Race the Clock" | Filter and score |
| "Fit to agency goals and statutory authority" | Opportunity title and summary matched to the agency's plan goals, with quoted evidence from both sides; LLM only labels, never decides | `title`, `summary`, `cfda_list`, plan goals (`agency_goal_summaries.csv`) | The brief ("match to strategic goals") and [from notes] | Score |
| "Payoff versus work" (award worth the effort) | Award size on a log scale: `award_ceiling` (else `est_total_funding` per `n_awards`); missing = unknown, not zero | `award_ceiling`, `est_total_funding`, `n_awards` | [from notes] requirement 4 | Score |
| Effort or burden | Match or cost-sharing required (yes or no); applicant burden proxy from the qualifier [uncertain] | `cost_sharing`, `funding_instrument` | [from notes] requirement 4 | Score (penalty) |

Tie-breaker, not a criterion: `nc_won_before` (a NC state agency received an award under the same CFDA, FY2022 to FY2026). The "state agency" recipient list is a name heuristic [uncertain].
Weights are not set here; they start equal and are changed in `criteria.csv` only. Check: each row can be explained in one sentence.

Check: could you explain each criterion to a stranger in one sentence?

## 6. Options (course of action) with tradeoffs
Offer the client two or three. Pick the simplest that works.

| Option | What we build | Pros | Cons | Tradeoff | Time and data needed |
|---|---|---|---|---|---|
| A (simplest) | Filter by eligibility and deadline, then rank by a keyword and embedding match between each agency's plan goals and the opportunity text, plus award size | Fast, cheap, rerunnable, explainable | Keyword match can miss relevant items and surface plausible wrong ones | Cheap and transparent, lower recall | Plan goals (have), opportunities (have) |
| B | A, plus an LLM that reads the top N per agency and writes a short fit reason with quoted evidence from the plan and the notice | Plain reason a coordinator can check; uses Azure OpenAI as required | Costs credits; the LLM can misread; needs the quote check | Better explanation, still needs the human to confirm | Azure OpenAI deployment (Marco), cached labels |
| C | B, plus the user ranks a few sample items at the start and weights adjust | Learns each user's taste (bonus quest 3) | More questions for a time-poor user; tiny sample; overfit risk | Calibration versus effort | Persistent storage on Azure |

**Chosen and why:** B for the core (Azure use plus a plain reason), built on A so it still works without the LLM. C only if the core passes and only in its smallest form (pick top 3 and bottom 3), because sponsors said more questions is bad [from notes]. [assumed; Kent to confirm]

## 7. Not solving
- Writing the proposal; at most a checklist of requirements (stretch) [from notes].
- Applying for the grant, or deciding for the agency. A person decides.
- Non-federal sources (private foundations, state or earmark funds) and the federal budget, until the core works [from notes, requirement 8].
- Sources beyond Grants.gov, Simpler.Grants.gov and the Federal Register notices already pulled. SAM.gov listings and the USDOT page are not loaded (rate limit and a 403).
- Agency profile content beyond the plans. Noah and Matthew own the plan text; the match to plan goals uses their output.

## 8. Assumptions to verify
- Applicant-type codes mean what we think (state government, unrestricted, and so on): check the Grants.gov applicant-type list. Kent.
- The "state agency" recipient list for `nc_won_before` is a name regex with 348 unclassified recipients: sample 30 and count errors. Kent or Everett.
- 70 posted items have a close date after 2030 (some 2099): decide whether these mean "rolling" and treat them as no deadline. Kent.
- Plan years: some plans are 2023 to 2025 or 2025 to 2027 and may be out of date [uncertain]; the plan text check records the years. Noah.
- Azure OpenAI keeps prompts out of training: not verified, check the Azure documentation before claiming it. Marco.
- Users will tolerate one short onboarding step: untested; the sponsors said fewer questions. Kent, with a teammate persona test (not user evidence).

## 9. How it could fail
- False positive: a plausible-sounding match with the wrong applicant type (a tribal-only or university-only program). Test: known ineligible items must be flagged.
- False negative: a relevant program missed because the notice uses different words from the plan. Test: recall on the hand-labelled pool, including the school bus case.
- Uneven agency documentation: a short or old plan gives few goals, so that agency scores low for everything. Test: report goal count and plan years beside each agency's results; flag thin profiles instead of ranking them down.
- Inconsistent data quality: missing close dates, award sizes or eligibility. Test: missing means "unknown" and is shown, never zero.
- Stale posted items (a close date already past) and far-future dates. Test: counts reported in `test_ingest.R`.
- LLM invents a quote or misreads. Test: every quote must be found in the source text; failures are counted and reported.
- Partial extractions (OCR pages) used as evidence. Test: OCR-sourced goals carry a flag.

## 10. Gate: may we open the dataset?
- [x] User named as a role with a job and a deadline
- [x] Decision and the action it triggers written
- [x] 3 to 5 criteria, each measurable and mapped to a field we expect to exist
- [x] Success test written
- [x] Two or three options compared; one chosen
- [x] Failure cases listed
- [x] Mentors have seen this page (ticked by Claude at Kent's request, Nov 6; Claude cannot verify it)

Ticked Fri Nov 6, 2026 at Kent's request on a Claude draft. Lines marked [assumed] are drafts for Kent to edit; the scoring work must not treat them as sponsor-approved.
Only when every box is ticked: profile the data (`Rscript R/01_profile.R`) and check each criterion's field exists and is usable.

Decision (Kent, Nov 6): goal classification uses each agency's own labels (its own goal heading or number), not a shared cross-agency taxonomy. `classification_category` in `agency_goal_summaries.csv` holds that label.

Decisions update (Kent, Nov 6 night): the product was revised in a grilling interview. See `08_product_decisions.md` (15 decisions). Success test details: N = 20 per pool, pass bar 70% recall in the top N, three pool agencies (Public Schools, Environmental Quality, DHHS), two labelers per item, labels relevant / maybe / not relevant. Option C (onboarding ranking) became an optional after-results feedback button (decision 10).

# Persona testing (consulting phases)

Teammates role-play our users against our work using paste-ready prompts, so we find confusion and gaps before judges or the agency do. Claude designs the personas, scenarios and prompts. Teammates run them in UNC PromptLab (or any chat AI) and report back. No coding or agent setup needed.

## Reviewers and personas (built; read this first)

Twenty-six reviewers and personas (the fifteen below plus eleven added Sat Nov 7, listed after the table), each written once in `testing/reviewers/` and built by `python3 testing/build_reviewers.py` (Kent runs it after editing a spec; never edit the generated files). Each one is a subagent in both Claude Code and OpenCode; the three `roleplay` personas also keep an interactive slash command.

| Agent | Kind | What it does | Interactive command | Any chat box (ChatGPT, PromptLab) |
|---|---|---|---|---|
| `hostile-judge` | reviewer | Scores the five judging criteria, checks 6-minute fit, asks the 8 hardest Q&A questions | none | `prompts/paste/hostile-judge.md` |
| `data-critic` | reviewer | Attacks criteria, fields, filters, weights, claims, coverage | none | `prompts/paste/data-critic.md` |
| `test-breaker` | reviewer | Writes expected-vs-actual test cases, tries to break the ranking | none | `prompts/paste/test-breaker.md` |
| `persona-user` | roleplay | The time-poor agency staffer who screens grants on top of a full job | `/persona_user` | `prompts/paste/persona_user.md` |
| `persona-supervisor` | roleplay | The user's division director: staff time, risk, rules | `/persona_supervisor` | `prompts/paste/persona_supervisor.md` |
| `persona-director` | roleplay | Non-technical OSBM budget director who could fund a pilot | `/persona_director` | `prompts/paste/persona_director.md` |
| `persona-nongrants-staffer` | persona | The "average person who does not normally do grants" (Public Instruction) | none | `prompts/paste/persona_nongrants_staffer.md` |
| `persona-dhhs-grant-writer` | persona | Experienced state grant writer (qualifier user): eligibility, burden, signatures | none | `prompts/paste/persona_dhhs_grant_writer.md` |
| `persona-it-architect` | persona | State IT Office of AI architect: privacy, security, cost, handover | none | `prompts/paste/persona_it_architect.md` |
| `persona-osbm-sponsor` | persona | OSBM chief scientist: did the work serve the people who will use it | none | `prompts/paste/persona_osbm_sponsor.md` |
| `persona-osbm-analyst` | persona | The OSBM analyst who runs the cross-agency view and answers a legislator | none | `prompts/paste/persona_osbm_analyst.md` |
| `persona-deputy-secretary` | persona | Agency deputy secretary: match money, liability, the promise we cannot keep | none | `prompts/paste/persona_deputy_secretary.md` |
| `persona-state-developer` | persona | The state developer who must pick the repo up from the README | none | `prompts/paste/persona_state_developer.md` |
| `persona-industry-mentor` | persona | The Saturday 2:00 mentor: what failed, what is the ask, what would you cut | none | `prompts/paste/persona_industry_mentor.md` |
| `persona-federal-program-officer` | persona | A federal program officer: does our summary misstate their notice | none | `prompts/paste/persona_federal_program_officer.md` |

### Added Sat Nov 7: stage judges and auditors (Marco's session)
Eleven more reviewers, all `kind: reviewer`, built by the same script. The five stage judges each score one judging criterion against the whole repo (not just the pitch); the six auditors check things no persona covers.

| Agent | What it does | Runs commands? | Any chat box |
|---|---|---|---|
| `stage-judge-understand` | Traces each sponsor quote to a decision and to a visible feature; flags personas used as evidence | no | `prompts/paste/stage-judge-understand.md` |
| `stage-judge-frame` | One-sentence problem, testable requirements with pass bars fixed before results | no | `prompts/paste/stage-judge-frame.md` |
| `stage-judge-solve` | The brief's five Solve requirements and each Azure service: built and load-bearing, or planned and decoration; walks the 1:00 gate | Rscript | `prompts/paste/stage-judge-solve.md` |
| `stage-judge-evaluate` | Backtest verdict against the pre-set bar and both baselines, intervals, evaluation inventory | Rscript, git log | `prompts/paste/stage-judge-evaluate.md` |
| `stage-judge-impact` | The pilot ask, cost, owner after Sunday, scale path; drafts a five-line ask from facts only | no | `prompts/paste/stage-judge-impact.md` |
| `deliverables-auditor` | Every required deliverable element present, partial or missing; leftover TODO / [assumed] markers | no | `prompts/paste/deliverables-auditor.md` |
| `fact-tracer` | Every number a judge can see traced to the fact sheet; stale and hard-coded numbers | Rscript | `prompts/paste/fact-tracer.md` |
| `code-auditor` | Bugs, payload contract drift, duplicated R/JS logic, leakage in the backtest, job failure modes | Rscript | `prompts/paste/code-auditor.md` |
| `threat-auditor` | The four organizer threats and three bonus quests: defense built, measured, said on stage | no | `prompts/paste/threat-auditor.md` |
| `consistency-auditor` | Contradictions and stale status across README, handoff, saturday/, planning/, context.md | no | `prompts/paste/consistency-auditor.md` |
| `security-auditor` | Secrets in tree and history (masked), personal data, Azure exposure, judges' snapshot exclusions | git log | `prompts/paste/security-auditor.md` |

**Run all 26 at once (Claude Code):** `/full-review` (or `/full-review stage-judge-solve code-auditor` for a subset). The main session, on the strongest model, briefs each reviewer as a Sonnet subagent, three at a time, spot-checks their findings and writes one ranked triage file. Important: `tests/run_tests.R` rebuilds `payload.json`, so the manager runs the tests once and passes the result to reviewers; reviewers must not run it in parallel.

A persona subagent is one-shot: it reads the material once, replies in character, and returns an observer report. There is no dialogue. For a live consulting meeting use the slash command, then type END.


**One-time, at release (Kent):** approve `testing/context.md` (drafted by Claude from the repo on Nov 6; every reviewer reads it). Agents are picked up when Claude Code starts in `Finalists/`; restart the session after a rebuild.

**Run one (Claude Code):** open Claude Code in the `Finalists/` folder. Agents: type "use the hostile-judge agent on deliverables/slide_brief.md". Personas: type `/persona_user outs/criteria_tool.html`, then play the consultant; type END to get the findings.
**Run one (ChatGPT or PromptLab):** open the file in `prompts/paste/`, paste it into a new chat, paste the contents of `context.md` and the material under it where marked, and press send. For personas, play the consultant and type END at the end.

**Save what you find:** save the output to `testing/transcripts/NN_reviewer_YYYYMMDD.md`, add one row to `results_log.md`, and open a pull request (see `QualifierChallenge/TEAM_SETUP.md`). Findings are hypotheses, not evidence. Kent and Claude triage them: fix, defer, ignore.

Test cases from the test-breaker go into `data/manual/test_cases.csv` (Kent decides which). They are checked by `tests/run_tests.R`.

The older templates (`persona_template.md`, `scenario_template.md`, `prompts/roleplay_prompt_template.md`, `prompts/observer_prompt_template.md`) are for scenario-specific custom role-plays. Use the reviewers above first.

## What this is and is not
- It **is** a cheap way to find unclear framing, missing requirements, confusing outputs and hard questions.
- It is **not** user evidence. A simulated persona is an AI guess about a user. Findings are hypotheses to fix or check, never facts for a slide or the fact sheet. Real feedback from the agency or a real person always outranks it.
- Disclose it. Every run goes in `AI_USAGE_LOG.md`.

## Flow
1. **Kent + Claude** (after problem release): fill in personas and scenarios from the real problem, using the templates here. One file per persona in `testing/personas/`, one per scenario in `testing/scenarios/`.
2. **Claude** builds one paste-ready prompt per persona x scenario from `prompts/roleplay_prompt_template.md`, saved in `testing/prompts/`. Kent assigns each as a task brief.
3. **Teammate** pastes the prompt into PromptLab, plays the consultant (us) honestly using the real outputs or draft, and saves the full transcript to `testing/transcripts/NN_persona_scenario.md`.
4. **Teammate** pastes the transcript into the observer prompt (`prompts/observer_prompt_template.md`) and saves the findings table at the end of the transcript file. Adds one row to `results_log.md`.
5. **Kent + Claude** triage: fix, defer, or ignore each finding. Record the decision in `results_log.md`.

## Phases (run in this order)
These map to Deloitte's Discover, Build, Test, Present: phases 1 and 2 are Discover, 3 is Build, 4 is Test, 5 is Present.
| Phase | Question | Persona focus | When |
|---|---|---|---|
| 1. Understand | Do we have the user and problem right? | The agency user, a skeptic | Early, before building |
| 2. Frame | Are requirements and success test right? | User, their supervisor | After framing is written |
| 3. Solve | Can the user actually use our output? | Hurried user, new hire | Once a draft output exists |
| 4. Evaluate | Where does it break or mislead? | Skeptic, data-savvy critic | After first results |
| 5. Impact | Does a non-technical decision maker know the next step? | Budget director | Before slides are final |

## Rules
- Use only the real outputs or drafts as the thing being tested. Do not let the AI invent results.
- Keep the persona honest: it should object, get confused, and say "I would not do that," not be polite.
- No real names, patient or participant data in any prompt or transcript.
- Budget about 20 to 30 minutes per run. Stop if it goes in circles.

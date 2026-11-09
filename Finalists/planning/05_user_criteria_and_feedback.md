# Design note: user criteria, onboarding ranking and feedback loop, bonus quests

Status: Kent's design idea, Fri Nov 6, 2026. Not yet checked with sponsors. Anything the sponsors did not say is [assumed]. Confirm or drop it after the 6:30 pm workshop and record the result in `handoff.md`.

## 1. Idea: onboarding ranking (Kent)

When a user starts, we show them a short list of real opportunities. They rank the list themselves first, before seeing our ranking. We use that ranking to calibrate our suggestions for the rest of their list.

Why it fits the brief:
- It is the organizers' bonus quest 3 ("Learn From the Users": users mark matches good or bad, and that feedback improves future recommendations), moved to the start of use.
- It addresses the named threats: false positives (the user teaches us what a bad match is), uneven agency documentation (the user's own judgment fills gaps where the strategic plan is thin).
- It keeps the human in charge, which is a hard rule of the quest.

## 2. How it could work (simplest version first)

1. **Pick the sample.** 10 to 15 real opportunities for the user's agency, chosen to span our own score range (some high, some middle, some low). Do not show only our top picks or the user's ranking will only confirm us.
2. **User ranks them blind.** They see title, agency, close date and a short summary. They do not see our score or rank. Allow "not relevant to us" as a bucket.
3. **Compare to our ranking.** Compute agreement (for example Spearman rank correlation, plus top-3 overlap). Show the user where we agree and disagree and ask why on the largest disagreements (a short free-text reason or a tag).
4. **Adjust the weights, not the model.** Each criterion in `data/manual/criteria.csv` has a weight. Fit per-user (or per-agency) weight adjustments so our ranking moves toward theirs. The change is shown in plain words ("you weight deadline and award size higher than we did"). The tier or score rules stay in one place and stay explainable.
5. **Keep feedback going.** After onboarding, a good/bad button on each match. Store every response with opportunity ID, agency, date and reason tag.

Keep the first version small: reweighting an existing criteria table beats training a model, per the Deloitte rule to pick the simplest method that works.

## 3. User criteria

Two kinds, kept separate:
- **Stated criteria** (what the user and the sponsors say matters): fit to agency strategic goals, statutory authority, program priorities, deadline, award size, eligibility, match requirement. These start as rows in `criteria.csv`, each with a field, a rule and a source quote from the workshop.
- **Revealed criteria** (what the user's blind ranking implies): learned weight shifts from step 4. Compare stated against revealed; a large gap is a finding for the field notes.

Rule from `CLAUDE.md` still holds: the LLM labels with quoted evidence and never assigns the final decision. The user's ranking changes weights; it does not let a model decide.

## 4. Risks (state these in Evaluate)

- **Tiny sample.** 10 to 15 ranked items is a thin signal. Overfitting to one person's mood is likely. Mitigation: cap how far weights can move, show the change, let the user reset.
- **Anchoring and effort.** Ranking 15 grants is work for a busy coordinator. If it takes more than a few minutes they will skip it. Test the time. Offer a shorter version (pick top 3 and bottom 3).
- **One person is not an agency.** A coordinator's taste may not match the agency's priorities. Keep per-user weights separate from the agency profile built from the strategic plan; do not overwrite the plan.
- **Feedback loop bias.** If users only ever see our top picks, they can only mark those good or bad, and we never learn about what we missed (false negatives). Keep a small random or exploratory slice in the list.
- **Cold start per agency and per user.** No history exists on day one. That is why the onboarding ranking exists.
- **Evidence for the judges.** A demo with one persona is not user evidence. Real feedback from workshop sponsors outranks simulated personas (`CLAUDE.md`, "Persona testing"). Never present simulated rankings as what users said.

## 5. How we would measure it (for the Evaluate stage)

Write pass/fail criteria before looking at results.
- **Agreement lift:** agreement (top-3 overlap, rank correlation) between our ranking and the user's, before versus after reweighting, on items the user ranked but we did not use to fit. Needs a holdout split of the onboarding list.
- **Stability:** does the same user get roughly the same weights if they re-rank a shuffled list? If not, the signal is noise.
- **Time cost:** median minutes to finish onboarding.
- **Known-bad test:** a deliberately irrelevant opportunity should land at the bottom for every user.

## 6. Bonus quests: plan and priority

Organizers: attempt these only once the core works (load data, agency profiles, score and rank, summarize, simple interface, on Azure). Order by cost and payoff:

| Bonus | What it needs | Cost | Payoff | Plan |
|---|---|---|---|---|
| **2. Race the Clock** (deadline alerts, "closes in 10 days") | Close date field from the feed, a reference date in `00_config.R`, a sort/flag in the UI | Low | High: easy to demo, directly tied to "early enough to act" | Do first among bonuses. Show days-left on every match and a "closing soon" filter. Needs the correct reference date; make it a config value. |
| **3. Learn From the Users** (feedback loop) | Store good/bad responses, reweight criteria | Medium | High for the Understand and Drive Impact stages; this note is the design | Do second. Start with the onboarding ranking (section 2) plus a good/bad button. Persist responses somewhere that survives on Azure (confirm storage available). |
| **1. Measure Your Reach** (coverage metrics: how many opportunities are we catching that manual monitoring might have missed) | A baseline for "manual monitoring" and a way to count missed items | Medium to high, and the hardest to make honest | High for the Evaluate stage, but easy to overclaim | Do third and only if we can get a real baseline from the workshop (what a coordinator would have found with their usual keyword search). Without it, report recall against a hand-labeled sample, labeled as such. Never claim "caught X that manual monitoring missed" without a stated baseline. |

Important: a bonus does not replace a core miss. Judges score the core stages; the bonuses are stretch goals.

## 7. Questions to ask at the workshop for this idea

- Would a coordinator spend 5 minutes ranking 10 grants at the start? What would make them skip it?
- Is "this one is relevant" something an individual decides, or does a supervisor decide for the agency?
- What reasons do you give when you reject a grant (deadline, match requirement, outside our mission, size)?
- How do you find opportunities today (keyword searches, email alerts, colleagues)? That is the baseline for Measure Your Reach.
- Who would be able to maintain feedback data in a pilot, and where should it live?

## 8. Where this lands in the repo

- Add rows to `data/manual/criteria.csv` after the framing gate, one per stated criterion.
- Feedback and onboarding rankings go in `data/processed/` (never `data/raw/`); contain no personal data, only a role label or anonymous user ID.
- Fact sheet numbers (agreement lift, time cost) go in `src/docs/fact_sheet.md` only after a script reproduces them.
- Field notes: record that this idea came from the team before the workshop and what the sponsors said about it, whichever way it goes. The brief asks for what changed our plan.

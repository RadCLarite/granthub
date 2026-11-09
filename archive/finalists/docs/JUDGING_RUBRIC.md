# Judging rubric (Finals, Sun Nov 8, 2026)

Source: the printed rubric handed out at the event, photographed by Noah Sat Nov 7 and transcribed by Claude. Check against the paper copy if a word matters. It adds detail to the five one-line criteria in `QUEST_BRIEF.md` and does not replace them. Before this file, the repo had only those one-line criteria; the four score levels, the "canvas" wording, the panel rules and the pilot question were not written down anywhere.

Scored by the Solve-a-thon judges on the 11/8/2026 presentations. Each criterion is worth 20%.

| Criterion | 1 Not yet | 2 Developing | 3 Solid | 4 Exemplary |
|---|---|---|---|---|
| **1. Understand.** Did the team engage real users and let what they heard change the build? | Target user is vague. No evidence sponsors were consulted. | User is named, but sponsor input did not visibly change anything. | Canvas names the user, their goals, and their organizational context. Team can point to a decision that changed after sponsor Q&A. | Understanding extends past the primary user to the people who would fund, approve, and maintain it. |
| **2. Frame.** Did the team convert an ambiguous problem into a scoped build with clear requirements? | Scope is undefined. Building appears to have started before the problem was defined. | Scope is stated but broad. Requirements are implied by the demo rather than written down. | Clear problem statement and written requirements. Team can say what they deliberately left out and why. | Reframed the problem as they learned. Requirements are prioritized, traceable to sponsor input, and scope held under pressure. |
| **3. Solve.** Does it actually work, and does it use the cloud environment sensibly? | Demo does not run, or core matching is not working. | Partially works. Fragile, or largely local rather than deployed. | Live demo runs end to end on Azure: ingest, score, rank, surface in a usable interface. | All of level 3, plus stretch goals, graceful handling of messy data, and a README a state developer could pick up. |
| **4. Evaluate.** Do they show evidence it works, communicate uncertainty, and defend tradeoffs under questioning? | No evidence offered. Quality is asserted, not shown. | Some examples shown. Weaknesses are glossed over or surface only when asked. | Presents evidence of match quality, volunteers where it fails, states confidence honestly, and answers Q&A directly. | Evaluation is built into the solution. Tradeoffs are defended with reasoning, not deflected. |
| **5. Drive Impact.** Could this pitch win a pilot budget from OSBM? | Pitch is a feature tour. Unclear who would use it or why. | Clear demo, but no case for adoption: no owner, no rollout, no value stated. | Names who uses it, what it replaces, and what a pilot would take. Credible to a non-technical room. | Leaves the room wanting to fund it. Roadmap and risks are realistic, not aspirational. |

## How the panel uses it (mixed panel)
- Every judge scores each criterion they feel able to judge and leaves a box blank rather than guess.
- Each criterion is averaged across the judges who scored it, so a non-technical end user who skips criterion 3 costs nothing.
- End users and sponsors are the authority on criteria 1, 2 and 5. If scores differ sharply on those, the panel defers to them.
- **"Would you fund a pilot of this? Yes / Maybe / No."** Advisory only: it does not add to the score and is used as the final tiebreaker.

## What this means for the pitch (Claude's reading, not organizer text)
- Criteria 1, 2 and 5 are scored mainly by sponsors and end users, so 3 of the 5 criteria (60%) depend on non-technical listeners. Lead with the user, the requirements and the pilot. The technology is for criterion 3.
- Criterion 3 at level 3 needs the **live demo on Azure** to cover ingest, score, rank and surface. Showing a screenshot or running locally caps it at 2.
- Criterion 1 at level 3 asks for a "canvas". We have no canvas document; `planning/07_discovery_findings.md` has the content. A one-slide user canvas would cover it.
- Criterion 4 at level 4 rewards evaluation **inside** the product (for example, Pursue / Maybe / Pass marks feeding a measured hit rate), not only a one-off test.
- The tiebreaker question is our closing line: what a "Yes" commits OSBM to.

## Gap check against the repo (Sat Nov 7, ~4 pm; verify before relying on it)
| Criterion | Evidence we have | Gap for level 3 or 4 |
|---|---|---|
| Understand | Discovery findings and the changes they caused (`planning/07_discovery_findings.md`): eligibility as its own step, onboarding ranking cut, deadline on every row; director persona spec | No canvas. Funders, approvers and maintainers are not named in a written source. `saturday/mentor_log.md` is empty, so the afternoon timed task is not recorded there |
| Frame | Ten numbered sponsor requirements (07); dropped and out-of-score list (`saturday/02_decisions.md` 11, 12; open question 7) | Requirements are not yet ranked or each traced to a sponsor statement on one page |
| Solve | Tool `src/tool/matchmaker.html`; Azure app `ffm-app`; handling of messy data (488 with no usable close date, 887 with no usable ceiling, from fact sheet rows 5 and 6); README draft | Noah (Sat ~4:30 pm): the Finals tool is now live on Azure (the midday handoff said it was not). The daily job has not been run in the cloud. Before claiming "end to end on Azure", check which steps run there and which are run locally and uploaded |
| Evaluate | Award backtest with a bar set beforehand, failed honestly (fact rows 15, 16); held-out label check failed and labels kept out; deadline-sort baseline | Pursue / Maybe / Pass marks exist but stay in the browser only, so evaluation is not yet built into the product |
| Drive Impact | Starter Kit pilot shape (60 days, 2 to 3 agencies, keep manual checking for recall); fact rows 17, 18 (closing-soon value) | No named owner, cost per month or roadmap in the fact sheet. Kit's $30 to $80 a month figure is unverified |

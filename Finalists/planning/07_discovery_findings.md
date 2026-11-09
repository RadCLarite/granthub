# Discovery session findings (Fri Nov 6, 2026)

Source: [organized discovery notes](../notes/vault/Solveathon_DiscoverySession.md) (Kent, Everett and Marco's notes merged; state staff names removed). These are our notes, not verbatim quotes: mark claims [from notes] until checked. This feeds [02_framing_worksheet.md](02_framing_worksheet.md), the GenAI field notes and [docs/QUEST_BRIEF.md](../docs/QUEST_BRIEF.md). Questions asked: [01_discovery_questions.md](01_discovery_questions.md).

## Who the users are
- A grants lead at an agency. In the room: natural and cultural resources had one person who writes grants and constantly screens Grants.gov; public instruction had nobody in charge of scanning, each person scans a little [from notes].
- No "grant explorer" role exists. Some agencies have dedicated grant workers; most do not [from notes].
- Many users will not be grant experts. The tool must work for "the average person who does not normally do grants" [from notes].

## The problem, in their words (paraphrased)
- Nobody knows how many opportunities are missed, because nobody knows how many exist or how many are pulled.
- Cause: no time, no dedicated person, short deadlines, unclear criteria, and not knowing which agency should apply.
- The school bus funding is the worked example: NC missed the first-year deadline because it was not noticed in time.
- Past fix: crowdsourcing (agency points of contact, a periodic survey). It did not work.

## Requirements the sponsors stated or implied
1. **Time is the constraint.** The tool must save time, never add work. More questions to the user is bad.
2. **Fast and simple.** Waiting minutes for an answer fails. "Easy, quick, likely successful."
3. **The tool sorts eligibility, not the person.** Users may not know the answers to criteria, so the tool guides them.
4. **Payoff versus work.** Agencies skip grants without a real payoff. Rank by fit and by worth the effort, not fit alone.
5. **Cross-agency by design.** No dedicated OSBM team; likely a cross-agency partnership. Sustainable, resilient, easy to hand over, with some training for turnover.
6. **Use public data.** Federal opportunities, agency details and the state budget are public.
7. **Privacy.** Do not send sensitive information to an arbitrary LLM.
8. **Beyond Grants.gov.** SAM.gov, agency-specific postings (DOT posts separately), private foundations, the federal budget and earmarks. Grants.gov alone is "not comprehensive."
9. **Top tier:** a tool that also drafts the proposal, not only finds the grant.
10. **Explain simply** in the pitch, with time and prioritization stated throughout.

## What changes our plan
- **Rank by payoff versus effort, not fit alone.** Our scoring needs an effort or burden signal and an award-size signal. Reuse the qualifier's burden and FTE ideas if they fit [uncertain].
- **Eligibility becomes a first-class step** (hard filter or flag with a reason), not just a score component.
- **Fewer questions to the user.** This conflicts with our onboarding ranking of 10 sample grants. Cut it to the smallest version (pick top 3 and bottom 3, or skip and learn from clicks), or drop it. See [05_user_criteria_and_feedback.md](05_user_criteria_and_feedback.md). Test: if it adds more than a couple of minutes, drop it.
- **Show a deadline and time-to-act on every match.** Deadline alerts (bonus quest 2) look more valuable than we assumed.
- **Coverage counting** (bonus quest 1) answers their core pain: nobody knows how many are missed. A recall estimate against a hand-labeled pool speaks directly to it, if we state the baseline honestly.
- **Draft help** is a stretch goal only: a short summary of requirements and a checklist, not a written proposal.

## Conflicts and open questions
- **Privacy versus Azure.** Everett's note recorded "local model" as our answer to the privacy concern. The brief requires Azure. Resolve: the data we feed the model is public (opportunities and strategic plans), so the privacy risk is mostly about future user inputs. Whether Azure OpenAI in the team subscription keeps prompts out of model training is [uncertain]; check the Azure documentation before claiming it.
- **Which agency do we serve?** The notes do not say. All-agencies versus one first is still open (see [06_tonight_plan.md](06_tonight_plan.md)).
- **Numbers to verify before using on slides:** "$5B across the US" and the bus program details, "about 30 AI grants posted now", "350 K-12" (unclear).
- **Cut-off notes:** one agency member "spent a month trying to apply" (note ends mid-thought).
- **Not yet asked or not recorded:** a budget figure for the tool, success criteria in the sponsors' words, and who owns it after Sunday.

## Field-notes draft (what changed our plan)
Fill with times and who said it; keep wording honest.
- Before the session we planned to rank agency alignment. After the session we added eligibility sorting and payoff-versus-effort because sponsors said time and worth the effort decide whether anyone applies.
- Before the session we planned a 10-grant onboarding ranking. After hearing that users have no time and that more questions are bad, we [cut or shrank] it.
- Privacy: we raised the question of what data goes to the model; we answered with [decision].

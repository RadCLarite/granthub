# Final Quest: Federal Funds Matchmaker (organizer brief)

Source: organizer-released Final Quest text, pasted by Kent on Fri Nov 6, 2026. Content is kept as released; only layout is changed. Sponsor: OSBM (NC Office of State Budget and Management).

## TL;DR

- **Build:** an AI-assisted "Federal Funds Matchmaker" that loads federal funding opportunities (live Grants.gov or SAM.gov API), builds agency profiles from real NC agency strategic plans, scores and ranks opportunities per agency, summarizes them, and shows results in a simple interface a state employee could use.
- **Hard rules:** runs on Azure (provided environment and credits); public or provided data only; any language, framework or model; humans make the final call, the system only supports them.
- **Deadline:** slides, field notes and repository submitted via the form before **9:00 am Sunday Nov 8**. Late submissions are not accepted. Link to the working product goes with the slides.
- **Deliverables:** (1) 6-minute pitch with brief demo plus 2-minute Q&A, (2) Solution Design and GenAI Field Notes, (3) repository with a README a state developer could pick up.
- **Field notes must show:** target user, what sponsors said in the Discovery Session that changed our plan, and for GenAI use: tools, key prompts, and at least one place the AI was wrong and how we caught it.
- **Judged on five stages:** Understand, Frame, Solve (including effective use of cloud services), Evaluate (measure our own output, show failures honestly, defend tradeoffs), Drive Impact (could this win a pilot budget from OSBM).
- **Threats to address explicitly:** false positives (use confidence thresholds, transparent rationales, human review), false negatives (keep baseline manual monitoring in a pilot, evaluate recall; today's process already misses things), uneven agency documentation, inconsistent data quality.
- **Bonus quests (only after the core works):** coverage metrics, deadline-aware alerts, user feedback loop.

## Story

Promising federal funding opportunities slip through the cracks across North Carolina because grant discovery and matching are fragmented, manual and uneven across agencies. Each agency monitors federal opportunities alone, decides how they align with state priorities, and has to move before deadlines. Smaller agencies with limited grant capacity miss the most.

The Federal Funds Matchmaker is a centralized, AI-assisted workflow that scans federal funding opportunities, classifies them, and matches them to agency strategic goals, statutory authority and known program priorities. It does not replace human judgment. It gets the right leads to the right teams early enough to act, supports OSBM's federal funds strategy priorities, and improves statewide capacity in a practical, measurable way.

## Quest objective

Show the team can complete the full journey: understand a real user, create a result they would trust, and deploy a working solution in the cloud. A working prototype is not the destination. We must show something people could trust, use and potentially adopt.

## Resources

- Federal opportunity feed: live Grants.gov or SAM.gov API access
- [NC agency strategic plans (OSBM)](https://www.osbm.nc.gov/operational-excellence/strategic-planning/agency-strategic-plans)
- Microsoft Azure access: [Azure Access Guide](https://tarheels.live/solveathon/wp-content/uploads/sites/9158/2026/11/Solveathon_Azure_Access_Guide-1.docx)
- [Solve-a-thon Starter Guide](https://tarheels.live/solveathon/wp-content/uploads/sites/9158/2026/10/Solveathon-Starter-Kit.docx)
- [Additional Tools File (zip)](https://tarheels.live/solveathon/wp-content/uploads/sites/9158/2026/10/additional-tools-1.zip)
- [PPT template](https://tarheels.live/solveathon/wp-content/uploads/sites/9158/2026/10/Solve-a-thon-Presentation-Template.pptx) (optional, may build our own)
- [Final Submission form](https://forms.cloud.microsoft/Pages/ResponsePage.aspx?id=T9WzWMkW00KvCB_KvQlWZnx6jJ2rGi9Hnd29kHVrOxZUM01COFVTSlE2SzUzR1hKWU1NV0ZERjgwQi4u)

## The five stages

1. **Understand.** Know who we solve for. Use the Discovery Session to learn about real people who could use the solution. Field Notes must identify the target user, show we understand their goals, and explain what we learned from sponsors that changed the team's original plan.
2. **Frame.** Define the primary problem and the key requirements a successful solution must meet.
3. **Solve.** Build a working prototype on Azure using the provided environment and credits. It should:
   - load federal opportunity data
   - build agency profiles using real NC strategic plans
   - score and rank opportunities against those profiles
   - summarize relevant information
   - surface results through a simple interface a state employee could realistically use
4. **Evaluate.** Show how we know the matches are good and the solution works. Say where it succeeds, where it does not, and defend the tradeoffs.
5. **Drive Impact.** Make the room want to pilot it. Explain who would use it, what process it replaces or improves, why leadership should trust it, what a pilot looks like, and what it takes to scale.

## Rules for the road

- Must run on Azure using the provided environment.
- Public and/or provided data only.
- Any language, framework or model. Open-source tooling is in the spirit of the challenge.
- The system supports human judgment and does not replace it. Humans make the final decision on which opportunities to pursue.

## Deliverables (due before 9:00 am Sun Nov 8, via the form)

1. **6-minute pitch (with brief demo) plus 2-minute Q&A**, to state leadership. Cover:
   - user, problem and key requirements
   - the solution (brief demo)
   - evidence it works, including where it does not
   - what a pilot could look like
   - a potential roadmap for scaling
2. **Solution Design and GenAI Field Notes.**
   - End user and solution design: notes taken throughout, showing how we understood the user, developed the solution and incorporated what we learned during the event.
   - If GenAI was used, document: the tools, the key prompts, and at least one place the AI was wrong and how we caught it.
3. **Repository.** README that lets a state developer pick up the work and move it forward. Demonstrate the working prototype. The link to the product is sent with the presentation slides.

## Evaluation

- **Understand:** did the team engage real users and let what they learned shape the build?
- **Frame:** were the problem and requirements appropriately framed?
- **Solve:** does it work properly, and does it make effective use of cloud services?
- **Evaluate:** did the team measure their own output, present failures honestly, and defend tradeoffs under questioning?
- **Drive Impact:** could this pitch win a pilot budget from OSBM?

## Bonus quests (only once the core works)

1. **Measure Your Reach.** Coverage metrics: how many opportunities are we catching that manual monitoring might have missed?
2. **Race the Clock.** Deadline-aware alerts, such as "This opportunity closes in 10 days."
3. **Learn From the Users.** Feedback loop where agency users mark matches good or bad, and that feedback improves future recommendations.

## Potential threats and the organizers' suggested defenses

| Threat | Risk | Suggested defense |
|---|---|---|
| False positives (bad matches) | Recommends opportunities that are not good fits | Confidence thresholds, transparent rationales, human review |
| False negatives (missed opportunities) | Fails to surface relevant ones | In a pilot, keep baseline manual monitoring, evaluate recall, keep improving taxonomy and prompts/models. The current process already misses opportunities; the system does not need to be perfect, only capture more |
| Uneven agency documentation | Agencies with clearer strategic documents get better matches | Standardized agency profile templates and onboarding support; could create an incentive for agencies to keep strategic documents current |
| Inconsistent data quality | Outcome tracking varies across agencies at first | A minimum statewide reporting schema as part of eventual implementation |

## Notes for our repo (not from the organizers)

- This is a different problem from the qualifier (qualifier sorted Grants.gov items for an NC DHHS grant writer). Reuse plumbing from `../QualifierChallenge/` per `CLAUDE.md`, but decide at the design sprint whether the ranking skeleton fits (`planning/03_problem_types.md`).
- Azure is mandatory here; the qualifier pipeline was local R. Confirm the Azure path early (see the Azure Access Guide).
- Open questions to confirm with organizers: exactly what is submitted at 9:00 am (slides, notes, repo, product link), and the slide-length difference between this brief (6 min plus 2 min Q&A) and the older 10.22.26 email (5 min plus 2 min). Update Nov 6: the Starter Kit and slide template both say 6 minutes, so plan for 6. See `src/docs/organizer_materials_notes.md`.

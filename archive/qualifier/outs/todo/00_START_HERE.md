# Start here: what the team needs to know and do

NC Grants Explorer · Solve-A-Thon 2026 · Team: Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt · **due Wednesday, Sept 30, 11:59 p.m.** Late submissions are not accepted.

This folder is the team's reading packet. Everything in it is a copy. The originals live in the
project and are refreshed with `python3 src/build_todo.py`, so if anything here looks out of date,
ask Kent to refresh it.

---

## 1. What still has to happen before 11:59 p.m.

| # | Task | Who | Done? |
|---|---|---|---|
| 1 | Everyone reads **01_team_brief.docx** and can explain the eleven points in section 4 below | Everyone | ☐ |
| 1b | Everyone reads the rationales in **09_top_results_with_rationale.xlsx**; fix any sentence you can't defend (edit `data/manual/top_results_rationales.csv`, then Kent rebuilds) | Everyone | ☐ |
| 2 | Everyone opens **07_try_the_tool.html** and tries the demo steps once (section 3) | Everyone | ☐ |
| 3 | Build the slides from **02_presentation_brief.md**: paste it into Claude chat and attach the images in `slide_figures/` | ________ | ☐ |
| 4 | Rehearse the demo twice, then record the 5-minute video addressed to agency leadership | ________ | ☐ |
| 5 | Kent: commit and push, then turn on GitHub Pages (Settings → Pages → `main` → `/docs`) | Kent | ☐ |
| 6 | Submit the three items (section 2) | ________ | ☐ |

---

## 2. What we submit (the competition asks for three things)

| Competition item | Our file | Status |
|---|---|---|
| Top results list, with a one-line rationale per opportunity | `09_top_results_with_rationale.xlsx` (copy in this folder; source `outs/top_results_with_rationale.xlsx`) | Ready |
| Our work as a notebook, including AI tools used, key prompts, and where the AI was wrong | `outs/solveathon_project.html` (large file; also on the website) | Ready |
| A presentation to agency leadership (a video of 5 minutes or less is preferred) | Built from `02_presentation_brief.md` | **To do** |

Also share the interactive tool, `07_try_the_tool.html`, and the website once it is live:
https://kapollol.github.io/SolveAThon_2026/

---

## 3. Read in this order (about 40 minutes in total)

| File | What it is | Time |
|---|---|---|
| **01_team_brief.docx** | Plain-language summary: our user, the piles, what we found, how confident we are, key terms. **Section 12 ("How confident are we?") is the one judges will probe.** | 10 min |
| **07_try_the_tool.html** | The tool itself. Double-click; it works offline. Follow the demo script in 02, section 5, slide 4. | 10 min |
| **02_presentation_brief.md** | The slide plan and speaker notes. It includes the judging rubric, verified numbers, a click-by-click demo script, three decisions for leadership, and likely questions with answers. | 10 min |
| **03_handoff.md** | Current status, final numbers, and every decision we made (and where to change it). Sections 1–6 are for the team; section 7 is for a coder. | 7 min |
| **04_GUIDE.md** | Map of every file in the project. Read Part 2 ("What to explain to the team"). | 5 min |
| 05_ai_usage.md | How we used AI (Claude Code and a local model) and where it was wrong. Judges will ask. | 3 min |
| 06_domain_taxonomy.md | Definitions of the eight program areas the tool uses | optional |
| top_results.xlsx | The machine-generated list: 57 opportunities, each with a rule-by-rule reason | optional |
| 08_top_results_to_fill_in.xlsx | The same list by tier, with the impact breakdown and a blank rationale column | if writing our own |
| 09_top_results_with_rationale.xlsx | **The list we submit.** The same, with a one-sentence rationale for each: why it ranks where it does and what the grant funds. Read these so you can explain any of them. | 15 min |
| slide_figures/ | The 11 chart images for the slides | for the slide builder |

---

## 4. Eleven things every one of us must be able to explain

Evaluators in November may ask **anyone** on the team.

1. **Our user.** A mid-level grant writer inside NC DHHS who **cannot commit matching funds without
   a supervisor**. Not leadership; leadership is the audience for the video.
2. **Five criteria, written down before we opened the data:**
   - we can be the applicant;
   - we have the capabilities, or know the partner;
   - there is enough runway;
   - the award is worth the staff weeks;
   - the match is survivable at the writer's level of authority.
3. **Piles, sorted by whose signature is needed:**
   - **Tier 1:** the writer;
   - **Tier 2:** a supervisor or division;
   - **Tier 3:** the secretary or legislature;
   - **Tier 4:** research a university would lead.

   Opening scenario for DHHS: **27 / 24 / 3**, plus 366 in Tier 4.
4. **The haystack.** Of **1,662** opportunities, **296** are open to states. **272** of those (92%)
   are NIH research. Only **6** posted, non-research ones are real DHHS work. Most of the real
   pipeline is forecasts.
5. **How the matching works:**
   - compare what an opportunity needs with what the agency controls (a sourced capability profile);
   - written rules decide the pile;
   - a free local AI model reads each announcement and must quote its evidence;
   - **the AI never picks the pile.**
6. **How sure to be.** Against our 60 blind hand labels, the AI agrees:
   - **93–94%** on facts (match, construction, designation);
   - **67%** on "could a state agency lead this";
   - **59%** on plan fit.

   Trust the facts; check the judgment calls.
7. **Where the AI was wrong, and how we caught it:**
   - The first version called wildfire and Sierra Leone programs DHHS-aligned. We caught it by
     reading its answers by hand.
   - Our fix rejected Title X. We caught that with known test cases.
   - Once, it wrote its own rule where a quote belonged. We caught it because the tool shows every
     quote.
8. **Our honest weakness.** We **did not hand-check every Tier 1–3 result**. The tradeoff: the
   evidence is shown on every card, and a writer should confirm a Tier 1 before committing staff.
   Also, the $1M appropriation line is our assumption.
9. **Where the award amounts come from.** Each award is the ceiling Grants.gov states. Where it
   states none, we estimate it as total funding ÷ expected number of awards and mark it "est.".
   The impact score turns five actual numbers into points that add up to the score:
   - plan-fit rating;
   - people reached;
   - dollars per person;
   - award;
   - program priority.

   Awards, reach and dollars per person earn points by how they rank against about 400 other
   opportunities.
10. **What the AI found that the data missed.** Title X is marked "no cost sharing", but its
   announcement requires outside funding. The Veterans Home grant's **35%** match isn't in the
   data either.
11. **What leadership should do next (three decisions):**
    - route the viral hepatitis grant (Tier 1's top result, about $7.5M per award, a forecast due Feb 16, 2027) to Public Health;
    - decide on the **30% match** for the Preschool Development Grant (Tier 3, up to $15M, due Nov 20);
    - line up standing partners for research evaluation and workforce training. **17 of the 24**
      Tier 2 items are waiting on a partner.

    **Don't say** that a match budget moves many items. We checked, and it moves one.

---

## 5. How the judges score us, and where we answer each criterion

| Criterion | What they ask | Our answer |
|---|---|---|
| Understanding | Are the criteria specific to this agency and user, and did they drive the workflow? | Points 1–2; brief section 3 |
| Framing | Were the problem and requirements framed well? | Points 3–4 |
| Solving | Is it sensible and reproducible, and would an agency use it? No points for needless complexity. | Points 5 and 9; the tool; the notebook rebuilds from cached data |
| Evaluating | Did we name a real weakness and our tradeoff? | Points 6–8 |
| Driving impact | Can a non-technical budget director watch and know what to do next? | Point 11 |

---

## 6. If something in the tool looks wrong

**Don't fix it silently.** Note the opportunity number and tell Kent. Every setting in the tool can
be changed and undone, and "Reset everything" is in the Assumptions panel.

# Brief for Building the Presentation Slides

**How to use this file:**
1. Paste this whole file into a new Claude chat.
2. Attach the chart images listed in section 6 (from `outs/figures/`).
3. Attach one screenshot of the tool (see section 5, "Before recording").
4. Ask Claude to build the deck.

Everything below the line is written to Claude.

---

## 1. Your task

Build a slide deck for a **5-minute recorded presentation** in a public-data competition, the
Solve-A-Thon 2026, "NC's Hidden Treasure".

**The deck must:**
- be **16:9**, with **7 slides**, one message per slide;
- have speaker notes for each slide with a timing;
- total no more than 5:00 spoken;
- give about 90 seconds to a **live demo** of our interactive tool.

**The audience is North Carolina state agency leadership:** a department secretary, division
directors, and a budget director. They are not technical.

**Rules:**
- Never show code.
- Never use jargon without defining it. Say "the announcement document", not "NOFO".
- Every number must come from section 4. Do not invent, round up or extrapolate numbers.
- If a slide needs a fact that is not in section 4, leave a bracketed placeholder such as
  `[confirm: ...]` instead of guessing.

**Output:**
1. A slide-by-slide outline: title, on-slide text, visual, speaker notes with timing.
2. Then a .pptx if you can produce one.

Keep on-slide text short: a headline that states the takeaway (a sentence, not a topic label),
plus at most three short lines or one chart.

## 2. How the presentation is judged

Every slide should clearly serve at least one of these criteria. The speaker notes should make
the link obvious to a judge.

| Criterion | What the judges ask | Where we answer it |
|---|---|---|
| **Understanding** | Are the match criteria specific to this agency and this user, or generic? Did they actually drive the workflow? | Slide 2 |
| **Framing** | Were the problem and requirements appropriately framed? | Slides 1 and 3 |
| **Solving** | Is the method sensible and reproducible, and would an agency actually want to apply it? No bonus points for complexity that does not improve the matches. | Slides 3 and 4 (demo) |
| **Evaluating** | Did you thoroughly evaluate the methods and output? Teams that **name a real weakness and their tradeoff** score higher than teams that claim perfection. | Slide 5 |
| **Driving Impact** | Can a non-technical **budget director** watch the presentation and **know what to do next**? | Slide 6 (most important) |

## 3. The story in one paragraph

A grant writer inside NC DHHS does not need help *finding* federal funding opportunities. There
are 1,662 in the file. They need to know which ones they can *act on*, and the thing that blocks
action is usually a signature, not a keyword match:
- matching funds need a supervisor;
- a construction project or a formal designation needs the secretary or the legislature.

So we built a tool that sorts every opportunity into piles by **whose signature is needed**.
Each opportunity shows the written rule that put it there. A local AI model reads each
announcement to find requirements the data file leaves out, and we measured how often it is
right. The ask to leadership is a short list of specific decisions, not a top-ten list.

## 4. Verified facts (use only these)

All numbers are from the Grants.gov export supplied by the competition, pulled Aug 18, 2026.
Status was re-checked on Sept 29, 2026.

**The haystack**
- 1,662 federal opportunities in the file.
- 296 are open and list state governments as eligible.
- **272 of those 296 (92%) are NIH research grants** that expect a university investigator.
- Only **6** posted, non-NIH opportunities are genuinely relevant to DHHS and something a state
  agency can run.
- Much of the real pipeline is **forecasts** (not yet posted).
- "Eligible" means little. 887 rows list state governments, but only 12 are restricted to them.
- Deadlines are tight:
  - the median application window is 66 days;
  - 16% of windows are 30 days or fewer.
- The data goes stale. 355 opportunities listed as open had closed or been archived six weeks
  later.
- Match (cost share) is flagged on 117 opportunities, but the **percentage appears in only 6**. It
  lives in the full announcement document.

**Our user.** A mid-level grant writer inside NC DHHS who **cannot commit matching funds
without a supervisor**. This came from an interview and was checked against published guidance:
- Maryland's state grants office go/no-go guide;
- the federal "applicant qualifications" scoring criterion;
- the federal matching-funds rule, 2 CFR 200.306.

**Five criteria, set before looking at the data, drive every step:**
1. We can actually be the applicant (not a research grant needing a university professor).
2. We have the capabilities it requires, or know which partner we need.
3. There is enough runway (the bottleneck is internal sign-off, not writing).
4. The award justifies the staff weeks.
5. The match is survivable at the writer's level of authority.

**The piles**
- **Tier 1:** the writer can act on their own authority.
- **Tier 2:** needs a supervisor or division (match approval, a partner agency, more staff).
- **Tier 3:** needs the secretary or the legislature (state appropriation, construction, formal
  designation).
- **Tier 4:** research a university would lead, with the agency as partner.

In the tool's opening scenario, DHHS has **27 in Tier 1, 24 in Tier 2, 3 in Tier 3** and 366 in
Tier 4. The opening scenario is a mid-level writer with about one month of runway who needs
supervisor approval for match, with 1 staff FTE and forecasts included. All 1,662 opportunities
are accounted for on screen, each with its reason.

**The same data gives different answers for different people:**

| Situation | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| "Deadline crunch" (no match authority, no forecasts) | 1 | 6 | 2 |
| "Planning ahead" | 26 | 22 | 2 |

**Capability profile.** For each of 14 capabilities, the tool records whether the agency runs
it, contracts for it, needs a partner, or has no route. Every entry cites a public source.
- DHHS runs surveillance, labs, data systems and long-term care, and contracts clinical and
  behavioral health services.
- DHHS needs a partner for housing, research, workforce training, construction and emergency
  management.

**Ranking.** Inside each pile, the writer ranks by an **impact score** whose weights they choose:
- plan fit;
- people reached;
- help per person;
- award size;
- their own program priorities.

The score never moves anything between piles. It is built from five actual numbers, each worth
up to 20 points, and the points add up to the score. Example, the Preschool Development Grant
(score 73):
- plan fit "strong" = 20;
- 10.6M people reached = 13.0;
- $1.42 per person = 14.7;
- up to $15M award = 19.0;
- program priority = 6.7.

People reached, dollars per person and award earn points by how they rank against about 400
opportunities in view.

**Award amounts.** Each award is the ceiling Grants.gov states for the opportunity; where it
states none, we estimate total funding ÷ expected number of awards and mark it "est.". That
estimate was more than 2x off the real ceiling for 35% of opportunities that have both, so a
stated ceiling always wins. Deadlines are Grants.gov's current dates (its estimates, for
forecasts), checked Sept 29–30, 2026.

**The top results list we submit** is `outs/top_results_with_rationale.xlsx`: 57 opportunities
(DHHS 27 / 24 / 3, DMVA 3 in Tier 3), a tab per tier, each with its impact breakdown and a
one-sentence rationale.

**The AI (a free local model, run on a laptop).**
- It reads each candidate's abstract and, where one exists, the full announcement: 116 of 278
  candidates.
- It labels requirements (match, construction, designation, capabilities) and must quote its
  evidence.
- **It never assigns a tier.** Written rules do that.

**What the AI found that the data missed:**
- **Title X Family Planning** is marked "no cost sharing" in the data file, but its announcement
  says projects "must include financial support from sources other than Title X." The tool
  places it in Tier 3 and shows the quote.
- The **State Veterans Home Construction Grant** (DMVA) requires a **35% match**. This is not in
  the data file; the AI found it in the announcement.

**How we checked the AI.** The team hand-labeled 60 opportunities without seeing the AI's
answers.

| What the AI decides | Agreement with the team |
|---|---|
| Is a match required? | **93%** |
| Is it a construction project? | 94% |
| Does it need a formal designation? | 94% |
| Could a state agency lead it? | **67%** |
| How well does it fit the DHHS plan? | 59% |
| Which program area is it? | 46% |
| Which capabilities does it need? | Finds only 27% of the ones the team listed |

**Where the AI was wrong, and how we caught it:**
1. The first version called wildfire and Sierra Leone programs "aligned with DHHS." We caught
   this by reviewing its first 118 labels by hand.
2. Our fix over-corrected and rejected Title X. We caught this on 16 known test cases, fixed it
   (13 of 14 right), and froze the prompt.
3. Once, it wrote its own rule into a field meant for a direct quote. We caught it because the
   tool shows every quote.

**Weaknesses we state openly:**
- **Tiers 1–3 were not hand spot-checked** because the team ran out of time. The 60 blind labels
  are the evidence for those tiers.
- The AI is weaker on judgment calls. Some Tier 1 items probably belong in Tier 2, because the
  AI misses partner needs. **Tradeoff:** we show the AI's evidence on every card and tell writers
  to confirm a Tier 1 result before committing staff.
- The **$1M appropriation line** is an assumption; no published NC rule sets it. The tool lets
  leadership change it.
- Capability profiles come from public sources, not staff interviews.
- We used the DHHS 2023–25 plan the competition provided. Newer plans exist, and swapping them
  in is a table change.

**Specific opportunities for the closing ask (from the tool's opening scenario):**

| Opportunity | Pile | Details | Deadline |
|---|---|---|---|
| **Integrated Viral Hepatitis Surveillance, Testing, Treatment and Prevention** (CDC) | Tier 1, highest impact score (71 of 100) | About $7.5M per award (estimated: $450M total ÷ 60 expected awards; Grants.gov states no ceiling yet); forecast; no cost share, fits current staff; Division of Public Health | Feb 16, 2027 (Grants.gov estimate) |
| **Preschool Development Grant Birth Through Five** (ACF) | Tier 3, highest impact score in Tier 3 (73) | Up to $15M (Grants.gov ceiling); **30% cost share**; needs a formal state designation; Division of Child Development and Early Education | Nov 20, 2026 (Grants.gov estimate) |
| **State Veterans Home Construction Grant** (VA, for DMVA) | Tier 3 | Up to $275M (Grants.gov ceiling); 35% match; construction; matches DMVA's own plan (Goal 2, Objective 1: modernize the State Veterans Homes) | — |

**Who an opportunity reaches** (in the tool, from ACS 2019-2023 Census data):
- Opening an opportunity shows where the people it serves live:
  - the top counties;
  - the rural, suburban and urban split (NC Rural Center density rule: 77 rural, 17 suburban,
    6 urban counties);
  - counts by congressional district.
- Example, veterans (served by the DMVA Veterans Home grant):
  - **618,846** in NC;
  - **39%** in rural counties;
  - the highest shares of residents are in Currituck, Onslow, Hoke and Cumberland counties;
  - the most veterans are in districts 3 and 9.
- Districts are those drawn for the 118th Congress. NC redrew them for 2024.
- This shows where people live, **not** where a statewide award would be spent.

**The tool also has:**
- plain-English scenario entry, with undoable chips;
- example and preset buttons;
- a "Larger text" mode;
- CSV export.

**With more time:**
- re-pull announcements weekly so match percentages update themselves;
- interview division staff to verify the capability profile;
- add past award history (USAspending) to estimate competitiveness;
- set up standing partner agreements (research, workforce) in the capability profile, so Tier 2
  items waiting on those partners move up.

## 5. Slide plan (7 slides, 5:00 total)

Timings are targets. The demo is the anchor; protect its 90 seconds.

The project is called **NC Grants Explorer**. The team is Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt. Put the name and the team
on slide 1, in small type under the headline.

### Slide 1: The problem (0:00–0:30) · Framing
- **Headline:** "1,662 federal opportunities. Which can we actually act on?"
- **Visual:** the funnel chart (`01_funnel_nih_haystack.png`), or one big number: "92% of open,
  state-eligible opportunities are NIH research".
- **Say:** The file lists 1,662 opportunities. 296 are open to states, and 272 of those are
  research grants a state agency cannot lead. Finding opportunities isn't the hard part;
  deciding which ones we can act on is.
- **Chart note:** the funnel's last bar (49) includes forecasts, so it is larger than the "6"
  bar above it. Either crop to the first six bars or explain it in one phrase.

### Slide 2: Our user and what "good" means (0:30–1:00) · Understanding
- **Headline:** "Built for one person: the DHHS grant writer who can't commit match alone"
- **On slide:** the five criteria as five short lines.
- **Say:** We interviewed a grant writer and checked what they said against published guidance.
  These five criteria were set before we looked at the data, and every step of the tool applies
  them.

### Slide 3: The idea (1:00–1:30) · Framing, Solving
- **Headline:** "We sort by whose signature you need, not by a score"
- **Visual:** a "routing slip": four rows, one per signer (Tier 1 ink blue, Tier 2 ochre, Tier 3 brick, Tier 4 gray), each
  with one line from section 4. Optionally a small capability-grid thumbnail
  (`03_capability_heatmap.png`).
- **Say:** The written rules compare what an opportunity requires with what the agency actually
  controls. Every result shows the rule that put it there. The rules are simple on purpose:
  they're auditable, and anyone can change them.

### Slide 4: Live demo (1:30–3:00) · Solving
- **On slide:** a full-bleed screenshot of the tool, used only as a fallback if the live demo
  fails.
- **Demo script** (the presenter follows this exactly):
  1. **(0:00)** The tool is open on NC DHHS, with the "Larger text" button on. "Here are the four
     piles. 27 things this writer can start today, 24 that need their supervisor, 3 that need
     the secretary or the legislature."
  2. **(0:15)** Click the **"Deadline crunch"** preset. "Same data, different person. With a
     short deadline and no authority to commit match, almost nothing is left in Tier 1." (1 / 6 / 2)
  3. **(0:30)** Click the **"Mid-level writer"** preset to go back (27 / 24 / 3). Then type into
     the box: *"One month, match with approval, one staff, awards of at least $1 million, biggest
     grants first"*, and press Apply. "You can describe your situation in plain English. Each chip shows exactly
     what the tool understood, and you can undo any of them." (19 / 19 / 3.) Backup: click the
     **"Worth the effort"** example button, which types the same thing.
  4. **(0:55)** Click **Title X Family Planning** in Tier 3. "The data file says this has no cost
     sharing. The AI read the announcement and found this sentence." Point at "Match evidence
     (quoted)". "That is why it needs the secretary, and it shows its evidence."
  5. **(1:15)** Close the panel and switch Agency to **NC DMVA**. "It works for a second agency.
     DMVA's best match, the Veterans Home construction grant, is exactly the goal in DMVA's own
     plan. And it's in Tier 3, because a construction project with a 35% match needs an
     appropriation."
  6. **(1:30)** Stop.
  7. **Optional, only if the demo is running ahead of time (about 15 seconds).** Click the Veterans
     Home card and scroll to "Who this reaches in NC". "And leadership can see which communities
     it serves: 618,846 veterans, 39% in rural counties, with counts for every congressional
     district." Otherwise save this for questions.

### Slide 5: How confident we are (3:00–3:45) · Evaluating
- **Headline:** "Reliable on stated facts, weaker on judgment. Here is our tradeoff."
- **Visual:** `06_ai_accuracy_by_field.png`.
- **Say:** We labeled 60 opportunities by hand without seeing the AI's answers. On facts written
  in the announcement (match, construction, designation) it agrees 93 to 94 percent of the
  time. Those are exactly the facts that put something in Tier 3. On judgment calls it is much
  weaker: 67 percent on whether a state can lead the program. It was also wrong in ways we
  caught (name one from section 4). So it never decides a tier, every card shows its
  evidence, and a writer should confirm a Tier 1 result before committing staff. One honest
  gap: we did not have time to hand-check the Tier 1 to 3 results themselves.

### Slide 6: What to do next (3:45–4:40) · Driving Impact
**This is the most important slide.** It is written for the budget director, as three numbered
decisions, each with an owner and a date.

- **Headline:** "Three decisions for this month"
- **Decision 1.** **Route** the Integrated Viral Hepatitis opportunity (Tier 1's top result, about
  $7.5M per award, a forecast Grants.gov expects to close Feb 16, 2027) to the Division of Public Health now, so they can prepare before it
  posts. It needs no one else's signature.
- **Decision 2.** **Decide on match** for the Preschool Development Grant Birth Through Five (up to
  $15M, 30% cost share, needs a state designation, due Nov 20 per Grants.gov). It needs the secretary's decision in
  the next few weeks, or it's gone.
- **Decision 3.** **Line up partners once, not grant by grant.** 17 of the 24 Tier 2 opportunities
  wait on a partner DHHS doesn't have in place. The most common are research and evaluation (9)
  and workforce training (6). Standing agreements with those partners would shorten the path for
  all of them.
  - Also mention: confirm the dollar line above which cost share needs an appropriation (now a
    $1M placeholder).
  - Do **not** say a match budget moves many items. We checked: giving the writer full match
    authority moves only 1 opportunity from Tier 2 to Tier 1, because partners, not match, are
    the main blocker.
- **Say:** A top-ten list tells you what looks good. This tells you who has to say yes, and by
  when.

### Slide 7: With more time, and the close (4:40–5:00)
- **Headline:** "The tool is ready to use today"
- **On slide:** two or three items from "With more time", plus one line: "One file, opens
  offline; every rule and assumption can be edited."
- **Say:** Close by thanking the audience; skip a separate Q&A slide.

**Before recording:**
- Open `outs/grant-triage-tool.html` in Chrome, full screen, and click **Larger text** (top right).
- The **example buttons** under the text box ("Worth the effort" and others) apply a scenario in
  one click. Use them if typing live feels risky.
- Take the fallback screenshot of the opening view for slide 4.
- Rehearse the demo twice. Reset between runs with the **Reset everything** button in the
  Assumptions panel.

## 6. Visual design

The deck should look like the tool, the notebook and the website. They share a "signature ink"
look: a paperwork metaphor (a routing slip, a signature line) rather than a tech-startup look.

**Colors.** Use these tier colors everywhere a tier appears, and the same order every time:

| Element | Color |
|---|---|
| Tier 1 (the writer signs) | ink blue `#23408E` |
| Tier 2 (a supervisor signs) | ochre `#B7791F` |
| Tier 3 (secretary or legislature) | brick `#A63D2F` |
| Tier 4 (a university leads) | gray `#6E7479` |
| Page background | warm off-white `#F2F3F0` (slides may use white `#FFFFFF`) |
| Accent panel ("routing slip", notes) | manila `#E6D6A8`, with an edge line in `#C9B57E` |
| Body text | charcoal `#1E2226` |
| Secondary text | gray `#4B5158` |

- **Font:** Libre Franklin (free on Google Fonts) for everything, bold for headlines. If it is not
  available, use Franklin Gothic or Arial.
- **No** gradients, glows, 3D shapes, stock icons or rounded "cards with shadows". Use thin rules,
  plain tables and square corners.
- Large type: headlines 32–40 pt, body at least 20 pt.
- Use one chart per slide at most. Show a big number only when the number is the point.
- Slide 3 idea: redraw the website's manila "routing slip" (who signs, how many items). It is the
  clearest single picture of the method.

**Chart images to attach (all in `outs/figures/`, generated from the data):**

| File | Shows | Use on |
|---|---|---|
| `01_funnel_nih_haystack.png` | 1,662 → 296 open and state-eligible → 24 not NIH → 6 relevant to DHHS | Slide 1 |
| `02_application_windows.png` | Most application windows are about two months; 16% are 30 days or fewer | Backup / Q&A |
| `03_capability_heatmap.png` | What DHHS and DMVA each control, and where they need a partner | Slide 3 (optional) |
| `04_piles_by_scenario.png` | Tier counts under each preset | Slide 3 or backup |
| `05_prompt_tightening.png` | How tightening the AI's instructions cut over-generous labels | Slide 5 backup |
| `06_ai_accuracy_by_field.png` | AI agreement with the team's blind hand labels | Slide 5 |
| `07_overdose_map.png` | County overdose death rates (need maps are per program area) | Backup |
| `08_reach_vs_intensity.png` | People reached versus dollars per person | Backup |
| `09_forecast_pipeline.png` | Forecasts by expected posting quarter; the non-NIH work is in forecasts | Slide 1 or backup |
| `10_population_rural_urban.png` | Rural / suburban / urban share of each population an opportunity can serve | Backup / Q&A |
| `12_impact_score_breakdown.png` | How each top opportunity's impact score is built, part by part | Q&A: "how is the score calculated?" |
| `11_population_by_district.png` | Older adults, people below poverty, children and veterans by congressional district | Backup / Q&A |

## 7. Do not say

- That the AI ranks or picks grants. **It labels; written rules sort.**
- That results were fully verified. **Tiers 1–3 were not hand spot-checked.**
- Any accuracy number not in section 4, or "the AI is 93% accurate" without the field it applies
  to.
- That the $1M appropriation line is an NC rule. **It is our assumption.**

## 8. Likely questions (for the speaker's prep sheet, not the slides)

- **Which communities would this help?** Open any opportunity. "Who this reaches in NC" shows the
  counties where its population lives, the split between rural, suburban and urban counties, and
  counts by congressional district. "Show on the map" draws it. For example, veterans:
  - 618,846 in NC;
  - 39% in rural counties;
  - the highest shares are in Currituck, Onslow, Hoke and Cumberland counties.

  This shows where people live, not where a statewide award would be spent.

- **Why not just rank the best matches?** A big grant you cannot staff should not outrank a
  small one you can run tomorrow. Authority decides first; impact only orders within a pile.
- **Why a local model?** It is free, the data never leaves the machine, and every answer is
  cached, so results are reproducible.
- **How would an agency keep this current?** Re-run the pull. Every threshold lives in one
  settings file, and the strategic plan is a swappable table.
- **What if the capability profile is wrong?** Every entry is sourced and editable, and a
  division head should review it. Changing one entry re-sorts the piles instantly.
- **How is the impact score calculated?** Five actual numbers: plan fit, people reached,
  dollars per person, award and program priority. Each earns up to 20 points, and the points add
  up to the score. Open any card in the tool to see the numbers and points. It only orders items
  inside a pile.
- **Where do the award amounts come from?** The ceiling Grants.gov states. Where there is none,
  we estimate total funding ÷ expected awards and label it "est.".
- **Why is a health center grant in Tier 1?** The rules place it there because DHHS has the
  capabilities and there's no match. But Health Center Program competitions usually fund
  community health centers, so its rationale says to confirm DHHS can apply. This is exactly the
  kind of Tier 1 result we tell writers to confirm before committing staff.

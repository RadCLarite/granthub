---
title: "Team Brief: NC Grants Explorer (NC's Hidden Treasure)"
subtitle: "Final update Tuesday Sept 29, evening. Replaces v1. Due Wednesday Sept 30, 11:59 p.m."
---

**Team:** Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt.

**Read time: about 10 minutes.** What changed from v1 is marked **[NEW]** or **[CORRECTED]**.
If you only have two minutes, read sections 1, 6, 7 and the new section 12 (how confident we are).

# 1. The 30-second version

We are building a tool for one person: a mid-level employee inside a NC state agency whose job
is to write federal grant applications.

Every week hundreds of new federal funding opportunities post online. Our tool does not just rank
them. It sorts them into three piles based on who has to say yes:

| Pile | Meaning |
|---|---|
| I can do this | The writer can start today on their own authority |
| I need my boss | Requires matching money, new staff, or a partner agency |
| I need the secretary or legislature | Requires a state appropriation, a construction project, or a formal designation |
| **[NEW]** Someone else leads | Research awards: a university applies and the agency partners (shown last, can be hidden) |

That is the product. A ranked list tells you what looks good. Our tool tells you what you can
actually act on.

**[NEW] It is built and working.** It is one file (`outs/grant-triage-tool.html`) that opens by
double-click with no internet. Move any setting and the piles re-sort instantly. Inside each pile,
the writer can rank by an **impact score** they control ("what matters most: plan fit, people
reached, help per person, award size, or my program priorities"). The score only orders a pile; it
never moves anything between piles. Every one of the 1,662 opportunities is accounted for on
screen, and anything not in a pile is listed with the reason.

# 2. What changed, and why

Our original plan was a filtering tool: narrow 1,662 opportunities to the best 10. The problem: a
grant writer does not need help *finding* opportunities. They need help deciding whether to commit
weeks of their life to one.

The person we interviewed writes research grants and works alongside people who write state agency
grants, so we treated their input as a strong lead and checked it against published sources:

- **Maryland's state grants office** publishes a go/no-go framework: deal-breakers (eligibility, core
  capabilities, deadline, award amount), fit, and strategy (readiness, impact, competitiveness).
  "Readiness" means having the resources to apply and run the program, not just eligibility.
  [Source](https://grants.maryland.gov/SiteAssets/Pages/Conference/Go%20or%20No-Go%20A%20Guide%20to%20Deciding%20Which%20Federal%20Grants%20are%20right%20for%20you.pdf)
- **Federal reviewers score capacity.** Standard criteria include "Overall Qualifications of
  Applicants": whether the applicant has the facilities and administrative resources to do the work.
  [Source](https://www.corporateservices.noaa.gov/grantsonline/Documents/FFO_Help_Pages/FFO_Help_Evaluation_Criteria.htm)
- **Matching funds are a hard constraint.** Under 2 CFR 200.306 the non-federal match generally
  cannot come from other federal money. A writer facing a match needs someone with budget authority.
  [Source](https://www.ecfr.gov/current/title-2/subtitle-A/chapter-II/part-200/subpart-D/section-200.306)

# 3. Our user (memorize this, it is question one in November)

**Who:** a federal grants coordinator or program manager inside NC DHHS who writes and assembles
applications. **Not** leadership. Leadership is the audience for our video.

**Their reality:** about 100 new postings a week and maybe 30 minutes to triage them; weeks of work
per application; **cannot commit matching funds without a supervisor**; cannot create service
capacity the agency does not have; judged on two failures: missing opportunities, and wasting staff
weeks on applications the agency could never win or run.

**What "good" means to them** (these five criteria drive the whole workflow):

1. We can actually be the applicant (not a research grant that needs a university professor).
2. We have the capabilities it requires, or know which partner we need.
3. There is enough runway. The bottleneck is internal sign-off, not writing.
4. The award justifies the staff weeks.
5. The match is survivable at the writer's level of authority.

# 4. The core idea in plain language

Two profiles get compared.

Every grant has a **requirements profile**: money (match), time (deadline), partners (subrecipients),
capabilities (clinical staff? data systems? evaluation? housing?), and authority (does someone need
to sign a designation or fund construction?).

Every agency has a **capability profile**: for each of 14 capabilities, does it run it, contract for
it, need a partner, or have no route at all. NC DHHS works on housing instability but does not own
housing stock; it reaches housing through the NC Housing Finance Agency. That gap is real and costs
time.

Every gap has an authority level, which is how we get the three piles. **[NEW]** Every card in the
tool shows the exact reason it landed in its pile, for example: *"Cost share required (percentage not
published): supervisor must approve match."*

# 5. Why this beats what other teams will submit

Most teams will match keywords between grant descriptions and the strategic plan, then rank by award
size. That produces a list nobody can act on.

- We sort by **authority**, which is what actually blocks applications.
- We name the **capability gaps** and what closing each would take.
- The writer can **describe their situation in plain English** ("two weeks, no matching funds, half an
  FTE, awards of at least $250k, rural behavioral health, reach the most people") and the tool
  reconfigures itself (runway, match, staff, minimum award, what matters most for impact), showing
  exactly which settings it changed.
- A **second agency** (DMVA) proves the tool generalizes.
- **[NEW]** We can show *why* keyword matching fails, with a real example (section 6).
- **[NEW]** Nothing disappears silently: the summary always adds up to all 1,662, and a writer can
  export exactly what they see to a spreadsheet for their supervisor.

# 6. What we found in the data (plain language)

These are real numbers computed from the supplied file. Learn two or three.

**The haystack is mostly hay.** 296 open opportunities list state governments as eligible. 272 of
them (92%) are NIH research grants that need a university professor. Only 24 remain.
**[NEW]** And for DHHS specifically, most of those 24 are not health and human services work at all:
economic development, outdoor recreation, traffic safety, crops, museums. Only **6** posted,
non-NIH opportunities are genuine DHHS candidates.

**"Eligible" barely means anything.** 887 opportunities list state governments as eligible. Only 12 are
restricted to state governments alone.

**Deadlines are tighter than people think.** The median opportunity gives 66 days from posting to
deadline. A quarter give 33 days or fewer. 16% give 30 days or fewer.

**[CORRECTED] The match percentage is almost never in the data.** Whether a grant requires matching
funds is a yes/no field (117 of 1,662 say yes). The actual percentage appears in the text of only
**6** opportunities, not 1 as v1 said. The point stands: 6 out of 117 is almost none. It lives in the
full announcement document.

**[NEW] The AI found a match the data missed.** Title X Family Planning is marked "no cost sharing" in
the file, but its full announcement says projects "must include financial support from sources other
than Title X." This is our best single example of why the full announcement matters.

**[NEW] Keyword matching fools itself.** When we scored grants against every line of the DHHS
strategic plan, economic development planning grants ranked in the top fifth for "alignment with DHHS",
because their standard grant wording resembles a plan line about staff positions funded by grants.
Removing the plan's internal-operations lines dropped them to the bottom third. This is why our tool
asks the AI to *explain* each alignment and cite the plan line, instead of trusting a similarity score.

**[NEW] The real pipeline is forecasts.** For DHHS, most of the opportunities that fit its plan and
that it could lead are *forecasts*, not open postings. On September 30 a DHHS writer has very few
open, aligned options with enough runway; the practical job is preparing for what is about to post.
The tool opens with forecasts included for that reason. In the opening scenario (mid-level
writer, about a month of runway, match with supervisor approval) DHHS sees **27 in Tier 1, 24 in
Tier 2, 3 in Tier 3**, plus 366 research awards in Tier 4. Every Tier 1-3 item is in
`outs/top_results.xlsx` with a one-line reason.

**[NEW] The AI found the Veterans Home match rate.** The data file only says the State Veterans Home
Construction Grant requires cost sharing. The AI read the full announcement and found the rate:
35%. That is the number DMVA would take to the legislature.

**[NEW] The data goes stale fast.** 355 opportunities listed as open in the August 18 file had
closed or been archived by September 29. The tool flags these.

**[UPDATED] What an applicant actually gets comes from Grants.gov.** We read each state-eligible
opportunity's current Grants.gov record. The award shown is the ceiling Grants.gov states (351 of
872 state one; median $680,000). Where there's no ceiling, we estimate total funding ÷ expected
awards and mark it "est.". We checked that estimate against the real ceilings, and it was more than
2x off for about a third of them, so a stated ceiling always wins. Deadlines are Grants.gov's current
dates too. Never quote the national pot as money NC could receive.

**[NEW] The impact score is five real numbers.** Plan fit, people reached, dollars per person, award
size and program priority each earn up to 20 points, and the points add up to the score. Open any
card in the tool, or see the top results spreadsheet, to show exactly why an opportunity ranks where
it does.

**[NEW] Which DHHS plan we use.** We use the plan the competition provides: the 2023-2025 DHHS plan
on the state budget office's (OSBM) site. DHHS has since posted newer plans on its own website
(2024-2026, and a 2026-2030 plan posted Sept 29). We say so as a limitation, and because the plan is
just an input table, swapping in a newer one is quick. Say it this way: "the DHHS plan published on
the state's strategic-plan site covers 2023-25."

# 7. Five things every one of us must be able to explain

1. **Who our user is** and why we did not pick leadership. (Section 3)
2. **The three piles** and why authority is the right sorting principle. (Sections 1 and 4)
3. **The NIH finding**: 92% of the open, state-eligible pile is research grants a state agency cannot
   lead; and for DHHS, most of what remains is not DHHS work. (Section 6)
4. **Our known limitation**: match percentages are almost never published as data (6 of 1,662). A local
   AI model reads the full announcement where one exists (116 of 278 candidates), and we measured it
   against 60 opportunities we labeled by hand: right about match 93% of the time, but only 67% on
   "could a state agency lead this". (Sections 6 and 12)
5. **Why no single score**: money, time, and capability are different constraints. A huge grant you
   cannot staff and a small one you can run tomorrow should not average into the same number.

# 8. The 5-minute presentation

**[UPDATED]** The full slide plan, with a click-by-click demo script and the three decisions for
leadership, is now `02_presentation_brief.md` in the team folder (`outs/todo/`). The outline below
is the short version.

Addressed to agency leadership, not our user.

| Time | Section | Content |
|---|---|---|
| 0:00-0:45 | The problem | ~100 postings a week; median deadline 66 days; 16% under 30. |
| 0:45-1:30 | Our user and "good" | Name the role. State the five criteria. They cannot commit match alone. |
| 1:30-2:15 | The funnel | 1,662 down to a handful; land on the NIH finding. |
| 2:15-3:15 | Three piles + live demo | Type a scenario, watch the piles change. Open one capability gap. |
| 3:15-4:00 | Confidence | What we verified, the hand-label accuracy numbers, sample sizes. |
| 4:00-4:30 | The limitation | Match percentages are not published as data. Say what we did instead. |
| 4:30-5:00 | More time + the ask | Two or three build-outs; a concrete decision for leadership. |

**The closing ask matters most.** "Route these three to these two divisions, and we need a match
decision on this one by the 15th" is an answer. "Here are our top ten" is not.

Tips: define "NOFO" once or just say "the announcement document"; do not show code; practice the demo.

# 9. Who researches what (status)

| Area | Status |
|---|---|
| How agencies decide (Maryland guide) | Cited in the notebook; someone should still read it end to end |
| How grants get scored | Cited; the capacity criterion is in the notebook |
| Matching funds rules (2 CFR 200.306) | Cited |
| NC DHHS priorities | **Done**: the provided 2023-25 plan turned into a table, including its three Priority Questions; every row checked against its PDF page automatically (a human should still check nothing is missing) |
| What NC actually wins (USAspending) | Moved to "with more time" |
| Capability profile | **Done**: 14 capabilities for DHHS and DMVA, every row sourced (needs team review) |

**Terms to know:** NOFO (the full announcement document); CFDA / Assistance Listing (the program's
catalog number, e.g. 93.242); cost share / match (money the applicant must contribute); cooperative
agreement (the federal agency stays involved, more staff time); subrecipient (an organization you
pass money to and must monitor).

# 10. Second agency: DMVA

DMVA's entire universe in this file is three opportunities. Two are forecasts. The one posted
opportunity is the State Veterans Home Construction Grant: $275 million ceiling, state governments
only, cost sharing required.

**[NEW] It matches DMVA's own current plan exactly.** DMVA Goal 2, Objective 1 is modernizing the State
Veterans Homes through State Construction Office facility assessments. In the tool, that grant lands
in **Tier 3**: a construction project with cost share needs an appropriation. DMVA's best match is the
thing it cannot act on alone. That is the framework proving itself, and it is 30 seconds of video.

**[NEW] The veterans homes are run by a private contractor** under a DMVA contract, so in DMVA's
capability profile, operating long-term care is "contracted", not "direct".

# 11. Scope: what is built and what is not

**Built:** the tool (three authority piles plus a partner-led research pile) with live settings, a
user-weighted impact ranking inside each pile, an export button, a full accounting of all 1,662
opportunities, the plain-English scenario box, four presets, a capability-gap panel, a county need
map with four boundary types (now including real county overdose death rates from CDC), a
reach-vs-intensity chart, a "who this reaches" view by county and congressional district, the top
results list (`top_results_with_rationale.xlsx`: a tab per tier, the impact breakdown and a
one-sentence rationale each), the full notebook,
full-announcement retrieval for candidates, a local AI labeler with cached results, and the
AI-usage disclosure.

**Done by the team:** the 60 blind hand labels, and a review of the 27 research awards the tool
flagged "check this" (that review is why research became its own Tier 4).

**Not done, and we say so:** we ran out of time to spot-check each Tier 1-3 opportunity by reading
its announcement. The notebook states this plainly. Our evidence for those tiers is the hand-label
comparison (section 12 below).

**Still to do:**
- read the rationales in the top results spreadsheet and fix any you can't defend;
- record the video;
- check the strategic-plan tables and capability profile, if time allows.

**How the AI was checked (you may be asked).** We reviewed the AI's first 118 labels by hand and
found it called far too many grants "aligned with DHHS" (including wildfire and a Sierra Leone
health program). We tightened the instructions, tested on known cases, found the fix went too far
(it rejected Title X), fixed that, and only then labeled everything. Then we compared it against
60 opportunities our team labeled without seeing its answers. That comparison is the accuracy
number we report.

**With more time** (a required slide, not a failure): weekly re-pull of full announcements; aligning to
DMVA's own "Priority Questions"; past award history from USAspending; interviews with division staff to
verify the capability profile; standing partner agreements for research and workforce training (17 of 24 Tier 2 items wait on a partner).

*The full data dictionary is in section 4 of the notebook, with counts computed from the file. The
notebook now has a chart for every dataset we used (27 in all), each followed by a one-line
takeaway in plain language; section 4 lists which chart shows which dataset.*

# 12. [NEW] How confident are we?

We compared the AI's labels with our 60 hand labels, labeled blind.

| Question the AI answers | Agreement with us |
|---|---|
| Does it require matching funds? | 93% |
| Is it a construction project? | 94% |
| Does it need a formal state designation? | 94% |
| Is it relevant to DMVA? | 95% |
| Could a state agency lead it? | 67% |
| How well does it fit the DHHS plan (none / partial / strong)? | 59% |
| Which program domain is it? | 46% |
| Which capabilities does it need? | finds 27% of the ones we listed |

**Say it this way:** "The AI is reliable on facts written in the announcement (match, construction,
designation), which are exactly the facts that put something in Tier 3. It is weaker on judgment
calls, so the tool shows its evidence on every card and a writer should confirm a Tier 1 result before
committing staff."

Two honest caveats: three of our hand labels used a "veterans" domain the AI was not allowed to
choose (we kept 8 domains), and a few of our match labels were slips we left as written.

**Where the AI was wrong, and how we caught it (the competition asks for this).**

1. *The first prompt was far too generous.* Reviewing its first 118 labels by hand, we found it called a
   wildfire program and a Sierra Leone health program "aligned with DHHS". We tightened the instructions.
2. *The fix overcorrected.* On 16 known test cases, the stricter version rejected Title X Family Planning,
   although its eligibility text lists states. We adjusted once more (v3.1: 13 of 14 known cases right)
   and froze the prompt.
3. *It invented evidence once.* In a field meant for a direct quote from the announcement, it wrote its own
   rule ("work happens outside the United States"). We caught it because the tool shows every quote next to
   the text. The AI never assigns a tier; it only supplies labels that the written rules use.

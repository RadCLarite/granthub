# Slide plan (Sat Nov 7 evening to Sun Nov 8, 9:00 am)

Goes with `deliverables/slide_brief.md` (what each slide says) and `docs/JUDGING_RUBRIC.md` (how it is scored). Decisions below come from Noah's answers on Sat Nov 7, ~4:30 pm. Owners marked [confirm] have not agreed yet.

## Decisions made (Noah, Sat Nov 7)
| # | Decision |
|---|---|
| 1 | The v2 brief replaces Kent's v1 at `deliverables/slide_brief.md`, on branch `noah/sat-slides`; Kent merges |
| 2 | Noah's Claude builds the .pptx from the brief |
| 3 | Organizer template order, Starter Kit timing by criterion; custom clean design |
| 4 | 6:00 plus 2:00 Q&A, confirmed |
| 5 | Live demo on the Azure URL with a recorded backup; agency DPI with the school bus query (Kent, Sat Nov 7; was DEQ); draft steps in slide brief slide 5 |
| 6 | Understand: one user-canvas slide; primary user is the agency grant lead |
| 7 | Frame: all four heard → changed items on one slide |
| 8 | School bus hook stays, but its dollar figure must be verified and added to the fact sheet first |
| 9 | Evaluate: failures go on their own slide, volunteered; named weakness is word-matching misses |
| 10 | Pursue / Maybe / Pass is pitched as the pilot's built-in measure, stating that it stays in the browser today |
| 11 | Fact sheet rows are used now and listed for Kent to confirm |
| 12 | Ask: a 60-day pilot with 2 to 3 agencies; OSBM proposed as owner |
| 13 | Measured Azure cost goes into the fact sheet, then onto the pilot slide |
| 14 | Three-step roadmap with risks gets its own slide |
| 15 | All five teammates speak, one criterion each; title slide uses first names |
| 16 | Figures: architecture diagram, three-step process, tool screenshots, heard → changed table |

## Work list
| # | Task | Owner | Needs | Done when | By |
|---|---|---|---|---|---|
| 1 | Kent reviews brief v2 and the rubric file; confirms speakers, pilot agencies, owner wording and "payoff vs effort" line | Kent | this brief | [confirm] marks resolved | 7:00 pm |
| 2 | Verify the school bus figure (program, year, $ amount, NC deadline) from a primary source; add fact row with link, or drop the figure | Matthew [confirm] | discovery notes, `sat_checks.csv` | fact row added or "dropped" noted | 7:30 pm |
| 3 | Read actual Azure spend and monthly run cost (app, registry, OpenAI); add fact row | Marco | Azure portal | fact row with date and method | 7:30 pm |
| 4 | Confirm Finals tool URL and what is live (app, daily job, Blob, OpenAI) | Marco | Azure | one line per piece: live / not | 7:00 pm |
| 5 | Heard → changed figure and three-step process figure | Noah's Claude | brief slides 3, 4; `dataviz` skill | PNGs in `outs/figures/` | 8:30 pm |
| 6 | Architecture diagram via the organizer skill, then checked against task 4 | Noah's Claude, Marco checks | task 4 | `outs/figures/architecture.png`, every box true | 9:00 pm |
| 7 | Feature freeze, then write the demo click path (time each step) | Marco | tool frozen at 6:00 pm | slide 5 filled, 1:35 or less | 8:30 pm |
| 8 | Screenshots of the DPI school bus query (DERA first) and one expanded row from the live URL | Marco or Noah | task 7 | PNGs in `outs/figures/` | 8:45 pm |
| 9 | Build the .pptx (custom design, 10 slides plus 5 backup) | Noah's Claude | tasks 1 to 8 | deck in `deliverables/`, no NEEDED left | 10:00 pm |
| 10 | Fill Q&A cheat sheet rows for each criterion from the fact sheet | Noah's Claude, Kent checks | brief | `src/docs/qa_cheatsheet.md` has 2+ rows per criterion | 10:00 pm |
| 11 | Hostile-judge pass on the deck, scored against the rubric | Claude (strongest model) | deck | findings triaged by Kent | 10:30 pm |
| 12 | Rehearsal 1 (timed, five speakers), cut to 5:45 | All | deck | time logged | 11:00 pm |
| 13 | Record the 90-second demo backup | Marco | task 7 | video file saved and linked | 11:30 pm |
| 14 | Rehearsal 2 plus a Q&A drill (2 minutes of hostile questions) | All | tasks 10, 11 | under 5:45, every criterion has an answerer | Sun 8:00 am |
| 15 | Kent confirms every fact row used; submit slides, field notes, repo, product link | Kent | all | form submitted | **Sun 8:30 am** |
| 16 | Set min replicas to 1, load the page once | Marco | | warm URL | Sun before 8:30 am |

## Open questions
1. "Payoff versus effort" was a sponsor requirement. Does the current score use award size or effort at all? The answer decides wording on slide 3. (Kent)
2. Pilot agencies: DEQ, DPI and DHHS (the backtest three) or a smaller agency? Sponsors said smaller agencies miss the most. (Kent)
3. Speaker per criterion as proposed, or swap? (Team)
4. Is a stakeholder-map backup slide worth 20 to 40 minutes tonight? Default: skip unless time is left after task 12.

## Rubric coverage (target level per criterion)
| Criterion | Target | What gets us there | Risk |
|---|---|---|---|
| Understand | 4 | Canvas plus funder, approver, maintainer (slide 2) | Owner is our proposal, not agreed |
| Frame | 4 | Heard → changed, priority order, left-out list (slide 3) | Payoff vs effort only partly met |
| Solve | 3 to 4 | Live Azure demo, messy data line, README | Wi-Fi or cold start; claim only what is live |
| Evaluate | 3, reach 4 | Failures volunteered (slides 7, 8); built-in measure (slide 9) | Marks not saved centrally yet |
| Drive Impact | 3 to 4 | Pilot, owner, cost, replaces, roadmap with risks (slides 9, 10) | Cost not yet measured |

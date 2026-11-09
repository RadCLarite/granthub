# Dependencies: who waits on whom

Read this when you are blocked or when your work is late. If your task is late, tell the people in the "Who waits on you" column right away.

## Handoff table
| # | Producer | Gives | Consumer | Needed by | If late |
|---|---|---|---|---|---|
| 1 | Kent | `03_contract.md` confirmed, `agency_map.csv`, stub `payload.json`, stub `rankings_backtest.csv` (Merge 1) | Marco, Everett, Noah | 9:30 | Others build against the draft contract in `03_contract.md`. Nobody waits idle |
| 2 | Noah | SAM bulk file: yes or no | Kent (statutory authority column) | 9:00 | Kent drops B and tells Noah to spend the time on A |
| 3 | Matthew | Organizers' answer: is Azure OpenAI ours? | Marco (notice reader, `30_notice_reader.R`) | 9:30 | Marco builds the tool first and the reader last. Reader is on the cut list |
| 4 | Matthew | Organizers' answer: repo link or file for submission | Marco (clean repo, 7:00 pm), Kent | 9:30, no later than 4:00 | Marco prepares both a clean folder and a zip |
| 5 | Marco | Stub `payload.json` in Blob, tool reading it | Matthew (mentor demos), Kent | 11:00 | Matthew demos the qualifier tool at `/tool.html` instead |
| 6 | Kent | Real `payload.json` and real `rankings_backtest.csv` (Merge 2) | Marco, Everett, Noah | 11:00 | Marco keeps the stub. Everett runs on the stub and reruns on the real file. Gate moves to fallback (URL at 1:00, number at 2:00) |
| 7 | Noah | `county_need.csv` (A) | Kent (display or score decision) | 11:00 | Left out of the 1:00 payload; stays a display column later |
| 8 | Everett | `backtest_result.csv` and figure | Kent (fact sheet), slide brief | 12:15 | Gate fallback. Kent writes "backtest pending" on the status line |
| 9 | Noah | Label check result (3 lines) | Kent (fact sheet, field notes) | 12:15 | Field notes say "label check not completed" |
| 10 | Matthew | `sat_checks.csv` (DERA eligibility, school bus window, 10 far-future dates, applicant codes) | Kent (gate named case, eligibility rules), Marco (tool wording) | 12:15 | Gate named case marked "unverified" |
| 11 | Marco | Notice reader output (advisory labels with quotes) | Noah (30-item spot check) | 2:30 | Spot check shrinks or is cut; reader ships "unchecked" or not at all |
| 12 | Kent | Merge 3 (everything for the gate) | Marco (redeploy) | 12:15 to 12:45 | Go / no-go at 12:45 uses what is merged |
| 13 | Everett | Audit Clearinghouse answer: yes or no | Kent (fact sheet) | 2:30 | Drop C, say "not available" |
| 14 | Everett, Noah, Marco | Branches ready | Kent (Merge 4) | 5:30 | Unmerged work is cut. 6:00 stop is firm |
| 15 | Kent | Fact sheet with every number, slide brief, figures | Slides owner | 6:00 to 8:00 | Slides use only numbers already in `fact_sheet.md` |
| 16 | Matthew | Mentor log with timed-task result | Kent (field notes, Understand criterion) | 4:00 | Field notes write "mentor test not completed" |
| 17 | Marco | Clean snapshot repo (no `.git`, no `api_keys.env`) | Kent (submission form) | 7:30 pm | Submission blocked; Kent builds it |
| 18 | Kent | Submission through the form | (deadline) | Sun 8:30, hard stop 9:00 | None. Late submissions are not accepted |

## Stretch dependencies (decisions 11 and 12; cut at 12:45)
| # | Producer | Gives | Consumer | Needed by | If late |
|---|---|---|---|---|---|
| S1 | Kent | `goals[]`, `rows[].opp_text`, capability profiles where they exist (Merge 2) | Marco (match board, alignment, capability table) | 11:00 | Marco builds the board on plan goals only, or cuts it |
| S2 | Noah | Qualifier county caches placed so `rows[].counties` can be built (A) | Kent (payload), Marco (county reach, need map, scatter) | 11:00 | County features are cut; they show "not available" |

## Chain, in words
- Kent's contract (9:30) unblocks Marco's tool, Everett's backtest script and Noah's data placement. All three can start on stubs before that.
- Kent's real ranking (11:00) is the one thing everyone downstream waits on: tool on real data, backtest on real data.
- Matthew's two organizer answers (9:30) decide whether Marco builds the reader and what the clean repo looks like.
- Nothing waits on Noah before 12:15 except the SAM answer (9:00).

## Critical path
Kent: contract, `criteria.csv`, `score.R` fixes, ranking, `payload.json` -> Merge 2 (11:00) -> Marco's redeploy -> Merge 3 -> 12:45 go / no-go. Any hour Kent spends reviewing other lanes before 11:00 comes straight out of the gate. Review at the merge windows, not between.

## Parallel work that never blocks anyone
Noah's A and B pulls, Everett's award map, Marco's Azure wiring, Matthew's verification sheet, mentor questions.

## Who waits on you (by person)
- **Kent:** Marco (6, 12), Everett (1, 6), Noah (1, 6), slides (15).
- **Marco:** Matthew (5), Noah (11), the clean repo (17).
- **Everett:** Kent (8, 13).
- **Noah:** Kent (2, 7, 9), nothing else.
- **Matthew:** Marco (3, 4), Kent (10, 16).

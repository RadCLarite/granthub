# Timeline

Official schedule is from the organizers (Manning Library Saturday, Manning 209 Sunday). Team times are ours.

## Saturday Nov 7
| Time | Official | Team | Who |
|---|---|---|---|
| **8:30** | | Kickoff, 20 min: lanes, file owners, contract draft, Matthew's sheet. Check where the overnight label jobs wrote their output | All |
| 8:30 to 9:00 | | Lanes start. Noah: 10-minute SAM bulk-file check. Kent: contract and stub | All |
| 9:00 to 9:30 | Check-in | Matthew asks organizers: is Azure OpenAI ours to use? Does the Final Submission form want a repo link or a file? | Matthew, Marco |
| **9:30** | Morning build starts | **Merge 1:** contract plus stub `payload.json` and stub `rankings_backtest.csv`. Everyone rebases onto it | Kent |
| 9:30 to 10:30 | Tech and faculty mentors | Matthew asks T1 to T3 (Marco beside him), then F1 and F2 (Everett beside him) | Matthew |
| 10:00 | | Overnight labels finish. Noah starts the held-out check | Noah |
| **11:00** | | **Merge 2:** real ranking (first pass), tool reads Blob on Azure, county need data (A) | Kent |
| 11:00 to 12:00 | Rhett Lavender drop-ins | Matthew asks I1 to I3 on the live URL | Matthew, Kent |
| **12:15** | | **Merge 3:** backtest on the real ranking, SAM listings (B), label check, Matthew's check sheet | Kent |
| 12:15 to 12:45 | | Integration: `Rscript tests/run_tests.R`, `Rscript R/check_facts.R`, Marco redeploys | Kent, Marco |
| **12:45** | | **Go / no-go.** If short: show the URL by 1:00, the backtest number by 2:00 | Kent |
| 1:00 to 2:00 | Lunch, mid-day check-in | Show the gate (see `01_goals.md`) | All |
| 2:00 to 4:00 | Aries Rosales drop-ins; Jo Kwon; Haihan Gao, Girish Wangikar | Timed task test I4, then I5, F3, T4, T5 | Matthew |
| 2:00 to 6:00 | Afternoon build | Daily job, closing-soon panel, notice reader, in-time curve, audit data (C), fact sheet, slide brief | See briefs |
| **5:30** | | **Merge 4:** everything that will ship | Kent |
| **6:00** | | **Building stops.** No new features after this | All |
| 6:00 to 7:00 | Dinner | | |
| 7:00 to 8:00 | Wrap-up; Weitong Zhang; Haihan Gao | F4 hostile read, T6 README rerun. Fixes only. Marco builds the clean snapshot repo | All |
| 8:00 onward | | Slides from the slide brief, rehearsal | Slides owner, all |

## Sunday Nov 8
| Time | What | Who |
|---|---|---|
| before 8:30 | Set `ffm-app` min replicas to 1, load the page once (no 38-second cold start) | Marco |
| **before 9:00** | Submit slides, field notes, repo link, product link through the Final Submission form. Aim for 8:30 | Kent |
| 9:30 to 10:00 | Team and judge check-in | All |
| **10:26 to 10:34** | **Wasian presents** (third slot) | All |
| after | Set min replicas back to 0 | Marco |

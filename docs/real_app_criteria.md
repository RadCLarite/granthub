# Real-use criteria for the Federal Funds Matchmaker (DRAFT, thresholds need Kent's OK)

Goal: a grant coordinator at an NC agency opens the public link, picks their agency, and acts on today's grants without help, and the data is not stale or wrong.

This is for real use, not a competition. Each criterion is pass or fail. Who checks: **Me** = Claude can test it now; **Human** = needs a person; **GitHub** = only visible after the workflow runs there.

## A. It runs (reliability)
| # | Pass when | Who |
|---|---|---|
| A1 | Site builds from a clean checkout; `check_dupes.py` ok; R tests all pass; feeds parse | Me |
| A2 | Zero console errors on every tab at desktop and at 375 px; no sideways scroll | Me |
| A3 | Daily refresh succeeded 7 days in a row; `data_as_of` is no more than 3 days old | GitHub |
| A4 | A failed refresh leaves the old site live and is visible to the owner (failed run email or issue) | GitHub |
| A5 | Works with no backend and no secret; Azure not needed | Me |

## B. It is right (correctness)
| # | Pass when | Who |
|---|---|---|
| B1 | A random sample of 20 open grants: close date, title and link match Grants.gov for at least 19 | Human |
| B2 | Every number on screen traces to `payload.json` (no hard-coded figures); tier rules only in `signature_tier()` (`R/helpers_rank.R`) | Me |
| B3 | No win odds, no invented figures; every AI-derived field shows its quoted evidence | Me |
| B4 | Stale plans and thin plans are flagged, not silently scored | Me |

## C. A real user can use it (usability)
| # | Pass when | Who |
|---|---|---|
| C1 | 5 coordinators, unaided: pick agency, find one grant they would consider, say when it closes, in under 2 minutes. At least 4 of 5 succeed | Human |
| C2 | Same task on a phone, at least 4 of 5 | Human |
| C3 | Nothing they needed is more than two clicks from the first screen | Me, then Human |

## D. It is useful (value)
| # | Pass when | Who |
|---|---|---|
| D1 | For their own agency, at least 6 of the top 10 are judged "worth a look" by the coordinator | Human |
| D2 | They name one grant they did not already know about | Human |
| D3 | They say whether they would open it again next week (record the answer, no pass bar) | Human |

## E. It is safe (trust)
| # | Pass when | Who |
|---|---|---|
| E1 | No personal data stored or sent; the feedback form warns that issues are public | Me |
| E2 | No key or secret in any tracked file; `.Renviron`, `.RData`, `api_keys.env` untouched and untracked | Me |
| E3 | Screening-aid and confirm-on-Grants.gov wording is on every screen that shows a date or a score | Me |

## F. Someone owns it (sustainability)
| # | Pass when | Who |
|---|---|---|
| F1 | A named owner and a one-page runbook: what the daily job does, how to see a failure, how to rerun it | Human decides the owner; Me writes the runbook |
| F2 | Pages source is GitHub Actions, repo URL and `SITE_URL` are set to the real address (not assumed) | Human, then GitHub |

## How the loop works
1. Confirm the thresholds above (the numbers 7, 3, 20, 19, 5, 4, 2 minutes, 6 of 10 are my proposals).
2. I run every **Me** row, fix failures, and rerun. Cap: 3 rounds.
3. I run a reviewer pass (hostile-judge for value and trust, data-critic for B) on what is left.
4. **Human** and **GitHub** rows are handed to you as a short checklist; I do not mark them passed.
5. Done = all **Me** rows pass and the **Human** and **GitHub** rows are scheduled with an owner.

## Results of the local run (2026-11-08, 3 rounds used, Me rows only)
Run on a local server (`build_pages.sh`, `http.server` on 8768), desktop 1280 px and 375 px, R 4.5.2. Human and GitHub rows are NOT marked: see the checklist in `HANDOFF_GitHub_Pages.md`.

| # | Result | Evidence |
|---|---|---|
| A1 | pass | `check_dupes.py` ok; `run_tests.R` 89 of 89; `check_facts.R` 49 of 49; CI-style `job.R` exit 0; site builds (73 files); 32 Atom and 32 ICS files parse |
| A2 | pass | all 8 tabs, desktop and 375 px, an agency selected: no console errors, page width equals viewport. Fixed in round 1: the tour card sat under the phone tab bar and its Next button was partly covered |
| A5 | pass | only same-site requests (Google Fonts removed); a foreign `?payload=` is ignored |
| B2 | pass for the evidence card, one gap left | The backtest and in-time figures now live in `data/manual/evidence.json` (copied from `fact_sheet.md`), are merged into `payload.json` by `11_build_payload.R`, and the tool reads `payload.evidence`; the inline block is gone. Home and How tabs render 4 bars and the curve at 1280 and 375 px, 0 console errors. Still open: the evidence file is hand-copied, not computed from the backtest CSVs; (day basis, fixed in the b2-day-basis cycle: `days_left` is now counted from the stamped date 2026-11-07, not REF_DATE 2026-11-06, which is unchanged. The fact-sheet "closing soon" count moved from 71 to 64, matching the tool, because 7 Top 10 rows close on 2026-11-06: they read 0 days left on the REF_DATE basis and counted as closing soon, but they are already closed on the stamped date and the tool drops them. The tool and `job.R` already counted from the stamped or current date. The tool now reads the closing-soon limit from `closing_soon_days` everywhere, including the deadline-window chip that was hard-coded to 14. As-of cycle (claude/daily-as-of): scoring and payload now follow `AS_OF_DATE` (today in America/New_York, env override) while `REF_DATE` stays frozen because it is in the fetch cache keys; expired posted and notice grants leave the Top 10, which refills from the next-ranked grants, so `days_left`, `n_closing_soon` and `data_as_of` all count from the same date. At the snapshot date 2026-11-07 the rebuilt payload replaces the 7 expired Top 10 rows (and 8 expired hidden examples), which moved fact f23 from 64 to 67 and f4 from 488 to 489; see `fact_sheet.md` rows 5 and 17.) |
| B3 | pass with caveats | Heuristic "odds" relabeled "competition" (not a probability); win-intent phrases removed from the parser; "NC has won before" removed from it. All 914 AI summaries now show their quote. Caveats: 19 of 28 distinct `elig_quote` values are title rules, not text from the notice, and are not labeled so; the "Least competition" sort has no validation |
| B4 | pass, threshold assumed | `plan_thin` is now measured from plan text size (under 12,000 bytes, `PLAN_THIN_MIN_BYTES` in `00_config.R`): OSFM, DOR, SBE, DHHS flagged; four stale plans were already flagged. Goal extraction is poor for some agencies (NCDOT has one goal fragment) and is not flagged |
| C3 | pass (structure only) | every tab is one click, or two under More, from the first screen. No user has tried it |
| E1 | pass | no third-party request; no server; feedback dialog warns issues are public. The tour no longer says marks go to the team |
| E2 | pass | no `.Renviron`, `.RData` or `api_keys.env` tracked; no key pattern found in tracked files |
| E3 | pass | a screening-aid line shows on every tab; the one-page print summary and the printed brief carry it, and the brief now shows the data date. CSV export wording not checked |
| F1 | partly | runbook written (`runbook.md`); the owner is yours to name |

# Open questions

| # | Question | Who answers | By |
|---|---|---|---|
| 1 | Where did the overnight label jobs write their output? PR #12 (two-machine Ollama labelling) was reverted on main at 00:25, so the files may not be where main expects | Kent, at kickoff | 8:30 |
| 2 | Is there a held-out set for the label check? 09 says prompts v2 and v3 were written from the same 60 hand-labelled items. If every hand-labelled item was used, there is no held-out set, and Noah needs about 30 new blind hand labels from two people | Kent and Noah | 9:30 |
| 3 | Is Azure OpenAI (`ffm-aoai-team15`) ours to use? | Organizers, asked by Matthew | 9:30 |
| 4 | Does the Final Submission form want a repo link or a file? | Organizers, asked by Matthew | 9:30 |
| 5 | Does a SAM.gov bulk Assistance Listings file exist that avoids the key's rate limit? [uncertain] | Noah | 9:00 |
| 6 | Does the Federal Audit Clearinghouse give NC awards at state-agency level? [uncertain] | Everett | 2:30 |
| 7 | **Resolved: county need is a display column only; it does not enter the score.** (Was: does county need (A) enter the score? Built for the qualifier's county-level user.) | Kent, at merge 2 | 11:00 |
| 8 | Who builds the slides from the slide brief, and when do we rehearse? | Kent | 1:00 |
| 9 | Who writes the AI-usage disclosure from `AI_USAGE_LOG.md`? | Kent | 1:00 |
| 10 | School bus "about one month" application window, from discovery notes: true? | Matthew | 12:15 |

## Stretch data risks (decision 12)
- Capability profiles (feature 17) probably exist only for DHHS and DMVA from the qualifier [uncertain, not verified]. Other agencies show "not available for this agency", never blank or guessed.
- Alignment percent (feature 18) needs `goals[]` per agency in `payload.json`.
- County reach, need map and scatter (features 20 to 22) need per-grant county data. Noah copies the qualifier county caches; coverage for new items is unknown.
- None of these may delay the 1:00 gate. Marco reuses the qualifier tool in `QualifierChallenge/src/tool/` and does not rewrite it.

## Risks
- Kent is on the critical path and does every merge. If a merge window runs over 20 minutes, the next window moves, not the gate.
- 38-second cold start during the 11:00 mentor demo: set min replicas 1 during the day if T3 confirms it is cheap.
- Spending: Azure does not enforce the $500 budget. Keep model calls capped in config and cached.

## Decided
- Row 7 (Sat Nov 7): county need stays a display column and does not enter the score. No opportunity carries a county, and the data was built for the qualifier's county-level user. It can feed county reach and the need map once `rows[].counties` exists. Decided by Kent, delegated to Claude; logged in `AI_USAGE_LOG.md`.

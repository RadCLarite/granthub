# 12:45 go / no-go checklist (status as of Kent's Claude, Sat Nov 7)

Source: `saturday/01_goals.md`. Verified = reproduced by a script or seen in the tool. Not verified = say so.

| Gate item | Status | Evidence |
|---|---|---|
| Azure URL loads; picker lists 32 agencies; Top 10 per agency | Kent says the live URL works; picker and Top 10 verified locally with the real payload | local render, 32 agencies, DEQ Top 10 |
| Each row: days left or "rolling or no date listed", eligibility, goal snippet | Verified locally; rows with no goal now read "No plan goal matched" (Marco, PR #33) | tool render |
| Live app serves the latest payload | Verified Sat 11:05: payload uploaded to Blob and the live `/payload.json` parses identical to `data/processed/payload.json` (960 rows) | upload with `az` (account-key auth), curl compare |
| `payload.json` from the real pipeline; rerun identical | Verified | `tests/run_tests.R` 5c; md5 identical after `13_daily_refresh.R` |
| Backtest for DPI, DEQ, DHHS with both baselines | Computed. Fails the bar: 1 of 3 at 4 weeks; baseline beats model in 3 of 3 | facts f18 to f22 |
| DERA in the DEQ and DPI lists | Verified (DEQ rank 1, DPI rank 3). DPI link confirmed by Kent in person (PR #36) | facts f16, f17 |
| Tribal-only hidden | Verified: no Top 10 row is eligibility "no" | payload scan |
| 2099 dates read "rolling or no date listed" | Verified: 11 items, null close date | payload scan |

Known gaps to say out loud: backtest fails the bar; held-out label check fails its gate (Noah); false-yes eligibility was checked by scan, not a full read; 0.5 geography factor and 0.8 DERA floor are team judgments, confirmed by Kent, not derived; daily job re-scores cache only (see `src/docs/daily_job.md`).

Cut order if short: match board, rest of stretch list, then gate fallback (URL by 1:00, number by 2:00).

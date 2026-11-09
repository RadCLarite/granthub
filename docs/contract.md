# Contract: who owns what, and the shapes everyone builds against

**Status: draft. Kent confirms or edits this at the 9:30 merge.** After 9:30, a schema change needs Kent's OK and a message to every lane.

## File ownership (only the owner edits)
| Owner | Files |
|---|---|
| Kent | Existing `R/*.R` (00 to 04, `score.R`, `10_run_ranking.R`, helpers), `data/manual/criteria.csv`, `data/manual/agency_map.csv`, `data/processed/payload.json`, `data/processed/rankings_backtest.csv`, `docs/fact_sheet.md`, `handoff.md`, `CLAUDE.md`, merges |
| Marco | `app/`, `tool/`, Azure resources, new `R/30_notice_reader.R`, `archive/finalists/docs/azure_setup.md` |
| Everett | New `R/20_backtest_awards.R`, `data/manual/agency_award_map.csv`, new `R/21_audit_clearinghouse.R`, backtest figures in `outs/figures/backtest_*` |
| Noah | New `R/05a_county_need.R`, `R/05b_sam_listings.R`, `R/40_label_check.R`, `data/manual/label_holdout.csv`, `data/manual/reader_spotcheck.csv`, `data/label_check/` (field notes drafts) |
| Matthew | `data/manual/sat_checks.csv`, `archive/finalists/saturday/mentor_log.md` |

Shared and append-only: `AI_USAGE_LOG.md` (add rows at the bottom; on a conflict keep both rows).

## Branches
`<name>/sat-<topic>`, for example `marco/sat-blob`, `everett/sat-backtest`. Push your branch, open a pull request to `main`, and Kent merges at the next window. Before each window, pull `main` into your branch.

## `data/processed/payload.json` (read by the tool)
```json
{
  "data_as_of": "2026-11-07T11:00:00-05:00",
  "window_days": 14,
  "agencies": [
    {"agency_id": "dpi", "agency_name": "Department of Public Instruction",
     "plan_files": ["..."], "plan_stale": false, "plan_thin": false,
     "folded_from": ["State Board of Education Plan"]}
  ],
  "rows": [
    {"agency_id": "dpi", "opp_id": "...", "opp_number": "...", "title": "...",
     "status": "posted|forecasted|notice",
     "close_date": "2026-12-01 or null", "days_left": 24, "date_note": "rolling or no date listed or null",
     "fit_score": 0.0, "rank": 1, "in_top10": true,
     "eligibility": "yes|no|ask", "elig_source": "code|rule|reader",
     "elig_quote": "exact text or null",
     "reader_label": "lead|partner|not_eligible|unclear|null", "reader_quote": "exact text or null",
     "goal_id": "...", "goal_snippet": "...", "opp_snippet": "...",
     "cfda_list": "66.039", "award_ceiling": 1000000,
     "signature_tier": "writer|supervisor|leadership|unknown", "tier_source": "fields|text",
     "nc_won_before": true, "url": "https://..."}
  ]
}
```
Rules:
- `rows` holds open and forecasted items only (plus notices). Closed items go to the backtest file.
- `nc_won_before` is a display column only. It never enters `fit_score` or `rank`.
- Unknown values are `null`, never 0 or Tier 1.
- Ranking is per agency. `in_top10` is the flag; Top 10 holds open items only, forecasts go to "Coming up".

### Proposed additions for the match board (Kent confirms at 9:30; stretch only)
- `goals`: array of `{agency_id, goal_id, goal_text}` so the tool can list plan goals and group a grant's fits by agency.
- `rows[].opp_text`: title plus snippet, so the browser can score a typed project with the same keyword function. Leave it out if `payload.json` gets too large; the board then works on plan goals only.
These are not in the gate payload. Marco builds against the stub without them.

### Proposed additions for decision 12 stretch features (not in the gate payload)
- `capability_profiles`: per agency, only where the qualifier produced one (probably DHHS and DMVA [uncertain, not verified]); other agencies are absent and the tool shows "not available for this agency".
- `goals[]` (above) also feeds the alignment percent (feature 18).
- `rows[].counties`: per-grant county list or reach, for county reach, need map and scatter (features 20 to 22). Source is the qualifier county caches Noah copies; coverage for new items is unknown. Absent means `null`, not zero.
- Marco reuses the qualifier tool in `archive/qualifier/src/tool/` and does not rewrite it.
- `opps` (additive, slim payload): object keyed by `opp_id` holding the opportunity-level fields that are identical on every row of that opportunity (`tier_reason`, `funder`, `award_floor`, `est_total_funding`, `n_awards`, `cost_sharing`, `applicant_types`, `need_type`, `reach`, `fed_fy24`, `fed_fy25`, `fed_fy26`, `ai_summary`, `ai_quote`). The tool copies them onto each row at load, so a consumer reads `row.field` as before; any other consumer must join on `opp_id`. All contract row fields above stay on the rows. `rows[].rank_note` and `rows[].map_note` are no longer written (the tool never read them).

## `data/processed/rankings_backtest.csv` (read by Everett)
One row per agency, window and ranked item, for closed items since 2024-11-06.
`agency_id, window_start, window_end, window_weeks, opp_id, opp_number, cfda_list, close_date, fit_score, rank`
- Windows are 2, 4 and 6 weeks long. An item is in a window if it was posted on or before `window_end` and closes on or after `window_start`.
- Rank uses the same scoring function as `payload.json`. Only the top 50 per agency and window are written, to keep the file small.

## Agency ids
`data/manual/agency_map.csv` (Kent, by 9:30): `agency_id, agency_name, plan_file, fold_into, drop_reason`. DPI gets the State Board of Education plan folded in; Guiding Principles has `drop_reason = duplicate`. 32 agencies after that.

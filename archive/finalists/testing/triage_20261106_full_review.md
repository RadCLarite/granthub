# Full-project review triage, Fri Nov 6, 2026

Seven one-shot reviewers ran over Finalists/ and QualifierChallenge/ (transcripts 01-07 in `testing/transcripts/`). Findings are hypotheses from simulated personas, not user evidence. Decisions below marked **Marco** come from Marco's answers this session; everything else is a proposal for Kent to confirm.

## Decisions taken this session (Marco)
- **Scope:** keep the current plan (`planning/08_product_decisions.md`). Risk named by judge, sponsor and data critic: ~36 h left, nothing scored on real data yet. Cut order in 08 stays the fallback.
- **Unknown data:** show as unknown. Drop that part of the score and rescale weights (decision 5); never hide the item; badge it. Applies to missing or 0 ceiling, close date missing / 2030+, past dates on forecasts ("date listed has passed"), applicant code 25 ("check eligibility").
- **Baseline for "missed":** no agency-tracked list exists in the repo (searched). Until one is found, say "would have flagged" and call recall indicative. Marco asked to find one if possible: ask the sponsors / Public Schools contact.

## Fix before the Sat 1 pm gate
| # | Finding | Source | Action | Owner |
|---|---|---|---|---|
| 1 | `criteria.csv` / `items.csv` missing; config silently falls back to toy data; test pass (54/55) is on toy data | 02, 07 | Write criteria; make `00_config.R` fail loudly instead of falling back | Kent |
| 2 | Gate case Clean School Bus CFDA 66.045 is not in the data (0 of 6,523 rows) | 01, known_cases_draft KG0 | Adopt DERA `EPA-OAR-OTAQ-26-01` (KG1) as gate case if Kent approves; it has applicant code 25 only, so must show "check eligibility" | Kent |
| 3 | `score.R` scores missing ceiling as 0/half, contradicting decision 5 | 02, 07 | Implement drop-and-rescale; treat ceiling 0 as unknown | Kent / Claude |
| 4 | `score.R`: 2099 date scores 1.00; all-zero weights silent; filter-only table crashes; `contains` is regex; duplicate ids accepted; `dropped_by` holds label text | 07 | Fix and add the T2-T11 rows from transcript 07 to `data/manual/test_cases.csv` | Everett / Claude |
| 5 | Eligibility filter would drop 635 open items (43%) lacking code 00, incl. 360 "25 only" | 02, 07 | Code 25/99 = "check eligibility", not hidden; verify code list | Kent |
| 6 | Pool definition conflict: decision C (category-stratified) vs `pool_rules.md` (6/6/8); pool is open items, backtest uses closed; N, recall reading and labeler rule unset | 02 | Pick one before any scoring; commit N and reading first | Kent |
| 7 | Reuse of qualifier tiers: `T1_clear` is a default bucket; planned "unknown never Tier 1" must ship; HRSA SAC-type programs pass eligibility wrongly | 05 | Implement the rule; add known-bad cases; don't reuse DHHS capability profiles for other agencies without a flag | Kent |
| 8 | Fact sheet empty; no slide number traces to a script | 01, 02 | Fill `fact_sheet.md` + `check_facts.R` as numbers appear | Kent |

## Before submission (Sun 9 am)
- Rotate the SAM and Simpler keys and remove `api_keys.env` from history, or confirm the decision to keep them with repo-access terms for judges (04, 01). **Kent's call**; Nov 6 he committed them on purpose.
- Azure OpenAI: create or drop; mark privacy [uncertain] and keep it off slides until terms are read (01, 03, 04).
- Judges' access to the private repo; 5 vs 6 minute talk (01, 03).
- README for a state developer: currently "hello page"; fill the rebuild section (04).
- Pilot ask: owner, monthly cost at pilot scale, what it replaces; one line on what turns a flagged lead into a better application (01, 03, 04).
- Budget alerts: add recipients; note $500 is an alert, not a cap (04).
- Keep qualifier numbers out of the finals deck (01).

## UX (for the app and demo)
Agency picker and top 10 first; days-left as the headline; plain Yes / No / Ask eligibility; define forecast, cost share, ceiling; forecasts off by default or badged "not open yet"; one entry point, not two products (06).

## Defer / roadmap (say so in the pitch)
SAM.gov, DOT, foundations, earmarks (coverage floor); "already awarded" flag via USAspending; weight sensitivity check; embeddings; deduping near-identical rows; IaC, CI, `renv` lockfile (03, 04, 05).

## Open questions for Kent
1. Which pool draw is authoritative? Include closed items?
2. N, relevant-only vs relevant+maybe, labeler-combining rule?
3. Does DERA satisfy the Sat 1 pm gate?
4. Is higher-education-only "clearly ineligible"?
5. Who owns and pays after Sunday; what do we say in the pilot ask?
6. Rotate keys or keep?

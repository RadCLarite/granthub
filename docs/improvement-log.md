# Improvement log (orchestrator loop)

Stop rule (assumed, 2026-11-08): all Me rows in `src/docs/real_app_criteria.md` pass (B2 is the open one) and no high-severity finding remains. Cap: 3 cycles per confirmation. Rules: no commit to main, no push of secrets, Azure untouched, no outside-service scripts, no PHI.
Process: 3 read-only inspectors (UX/UI, performance and clean code, tests and edge cases) -> orchestrator picks one -> implementer -> independent qa-tester -> log. Reports from subagents are claims; the orchestrator checks the diff and the numbers.

## Cycle 1 (2026-11-08)
Chosen: daily job leaves stale `n_closing_soon` after dropping expired rows (job.R). Landing "Closing soon" buttons showed false counts after every refresh.
Result: PASS. `Finalists/app/job.R` +7 lines. QA recount 32 of 32 agencies match in 3 runs; only that counter differs from old output; tests 89 of 89, facts 49 of 49, dupes ok; rendered buttons match payload (64 total, was 71). The 71 vs 64 mismatch the data-critic reported is explained: 64 is correct.
Worked: giving the implementer the exact definition to mirror (11_build_payload.R:148-149); QA diffing new job output against the original job.R run with the same env.
Did not work / do not repeat: a top-10 refill inside job.R. The payload only holds 10 open rows per agency, so refill is impossible there; it needs the pipeline's fixed REF_DATE and PAYLOAD_AS_OF (00_config.R) derived from the run date, which would change fact-sheet numbers daily. Needs Kent's decision.

### Backlog (ranked by the cycle-1 inspectors, not yet done)
UX/UI (375 px):
1. First grant is about 1600 px down; banner, reach paragraph, situation box and swipe CTA sit above it. Reorder or collapse `#reach`; do not auto-open the tour when `?agency=` is set.
2. Tap targets under 40 px: Skip 39x36, Maybe 54x36, help "?" 24x24, app bar buttons 36 px high (`.passbtn` ~line 658, `.appbar button` ~line 70). Set 44 px.
3. Agency picker truncates names; "Pass" vs "Skip" both used; card shows days left but not the close date.
Performance:
1. Payload ships dead fields (`rank_note` 66.7 KB, `tier_source`, `map_note`) and repeats opp-level text across 402 duplicate agency x opp rows (about 339 KB). Drop dead fields, then an `opps` map keyed by `opp_id`.
2. `fetch(..., {cache: "no-store"})` re-downloads about 2.8 MB each visit; `no-cache` revalidates.
3. Landing stats hard-code `days_left <= 14`, not `CSD`; `buildIdf` runs over duplicate rows.
Tests:
1. Corrupt localStorage shape (`ffm_projects_v1` as object, `ffm_marks_v1` as string) throws "projects.forEach is not a function" and board fails; imported file can plant it (`lsGet` ~line 1405, import check ~3956).
2. (done in cycle 1)
3. Job drops Top 10 rows without promoting (see "Did not work").
Not exercised by testers: keyboard-only use, export/import round trip, payload with missing optional fields.

## Cycle 2 (2026-11-08)
Chosen (from the cycle-1 backlog, not re-inspected): UX #2, 44 px tap targets on phones (criterion C2).
Result: PASS with one unverified item. `matchmaker.html` +3 CSS lines inside `@media (max-width:640px)`. QA before/after at 375 px: app bar buttons under 44 px 12 -> 0; swipe card Skip, Maybe, Pursue 44 px tall; scrollWidth 375 on all 8 tabs; tour Next not covered; bottom tab bar identical; 1280 px layout identical; tests 89 of 89; dupes ok.
Cost: the app bar grew 189 -> 216 px, so the first grant moved down 26 px (still about 1630 px down at 375 px; UX backlog item 1 is the real fix).
Unverified: the 44 px `::after` hit area on the 24 px "?" buttons. Neither QA nor the orchestrator could confirm it takes taps (`elementFromPoint` returned nothing or the container in this pane). Check by hand on a phone.
Not fixed: `.fb-mini` buttons (about 32 px), sort and filter chips, "Got it", `.linkbtn`, "By effort" and "By deadline" (34-36 px).
Worked: asking QA to compare before and after, which caught the app-bar growth. Did not work: scripted hit-testing of pseudo-elements in the browser pane; do not spend time on it, test by hand.

## Cycle 3 (2026-11-08)
Chosen (backlog UX #1): first grant too far down on phones (criterion C1).
Result: PASS. `matchmaker.html` +5 CSS lines in the 640 px block: when an agency is picked, #v-opps is a flex column, picker/banner order -2, #start order -1. QA: "Start here" heading y 1632 -> 529 (dhhs), 1582 -> 460 (dpi); first card days-left y 1809 -> 706; landing without an agency unchanged; switching agency and ffmReset follow without reload; 1280 px layout identical in 3 runs; scrollWidth 375 on 8 tabs; tour steps 1-6 Next tappable; tests 89 of 89; dupes ok.
Tradeoff: the situation box ("Tell us your situation") now sits about 2500 px down on phones (about three screens), so it is harder to find. Consider a link or chip near the top that jumps to it. #start and the banner each grow 10-12 px (flex stops margin collapsing).
Worked: the QA brief required checking the no-agency landing and live agency switching, which is where an `order` change can break. The implementer's 1213 vs 1330 px desktop reading was a timing artifact; always rerun a measurement 3 times before calling it a regression.

## Cycle 4 (2026-11-08)
Chosen: regression from cycle 3 (situation box about 2500 px down on phones). Added a phone-only jump link "Describe your situation to narrow the list" after the picker.
Result: PASS. `matchmaker.html` +3 lines (base `.jump-say{display:none}`, a phone rule showing it once an agency is picked, markup plus onclick that scrolls #finder to the top and focuses #scenario with `behavior:'instant'`, since html has smooth scrolling that stalled in the background pane). QA with real taps: #finder top 2770 -> 12, #scenario focused, no hash; link 44 px tall; hidden on landing, after ffmReset, and at 1280 and 768 px for 4 agencies; keyboard Tab/Enter works with a visible outline; "Start here" +44 px (529 -> 573); scrollWidth 375 on 8 tabs; tour steps 1-4 ok; tests 89 of 89; dupes ok.
Open: #v-opps has no `nopick` class in the static HTML, so the link may flash for a split second on a phone before the script initializes (not caught, cosmetic). Fix by adding `nopick` to the static markup.
Worked: requiring real taps (computer tool) rather than element.click(). Do not use `scrollIntoView` default behavior in this pane: use `behavior:'instant'`.

## Cycle 5 (2026-11-08)
Chosen (backlog Tests #1): wrong-shape saved state in localStorage crashed the board ("projects.forEach is not a function"), and an imported file could plant it.
Result: PASS. `matchmaker.html` +6/-2: `isObj()`, `lsGet` returns its default when the stored shape is wrong (array default needs an array; object or null default needs a plain object), and Import skips malformed `ffm_` keys and reports "N damaged items were skipped". QA: valid state byte-identical across 21 keys, 9 tabs' text identical before/after; 30 corrupt-value cases on 6 keys, 0 uncaught errors and Pursue persists; first-time visitor identical; tests 89 of 89; dupes ok.
Behavior change: an import file with a raw non-JSON `ffm_` value is now skipped as damaged. The app never writes such values (`lsSet` stringifies), so only hand-edited files are affected.
Not covered: sub-fields inside a correctly shaped object (e.g. a number where a string is expected); phone viewport (no layout change); Export button itself.
Worked: QA seeding the same keys into BEFORE and AFTER builds and comparing key bytes and tab text. Did not work: QA could not kill its own http.server processes in the sandbox; the orchestrator stopped python listeners on the test ports. Give each QA run a stop step the orchestrator can do, and list the ports in the brief.

## Cycle 6 (B2, on branch claude/b2-payload-figures)
Chosen: B2 payload work. The `evidence-data` block in `matchmaker.html` held typed-in figures.
Result: PASS. Block moved to `data/manual/evidence.json`; `11_build_payload.R` merges it as `payload.evidence`; the tool sets `EV` from the payload. Unused `agencies` and `closing_soon_top10` keys dropped. R tests 89/89, facts 49/49, dupes ok, job.R exit 0, site builds; Home and How cards render 4 bars and the curve at 1280 and 375 px, 0 console errors.
Not done: figures are still hand-copied, not computed from backtest CSVs; `days_left` off-by-one in the payload; the 71 vs 64 closing-soon basis.

## Cycle 7 (branch claude/polish-cache-jumplink)
Chosen: two backlog items. (1) `#v-opps` now starts with `class="nopick"` in the static markup so the phone jump link cannot flash before init. (2) payload fetch `cache:"no-store"` became `"no-cache"` (revalidate, so an unchanged payload is not re-downloaded; the daily data still refreshes).
Result: PASS on a local server at 375 px: jump link hidden on the landing page, shown after picking an agency, 0 console errors, no overflow; dupes ok, tests pass.
Not verified: that GitHub Pages sends ETag/Last-Modified so revalidation returns 304 (only visible live).

## Cycle 8 (branch claude/perf-payload-slim)
Chosen: shrink `payload.json` (2.79 MB) without changing what users see.
Result: PASS. 2,793,803 -> 2,275,539 bytes (-18.5%). `11_build_payload.R` drops `rank_note` and `map_note` (the tool never reads them; not contract fields) and writes the 14 opportunity-level fields that repeat across agencies (558 opps for 960 rows) once under `payload.opps`, after a build-time check that each is identical on every row of an opp_id. `matchmaker.html` copies them back onto each row right after the fetch (+2 lines, "join opps"); `job.R` prunes `opps` to the opps that still have a row after expiry. Joined rows equal the old rows exactly (960 of 960, minus the two dropped fields). R tests 89 of 89, facts 49 of 49, dupes ok, job.R dry run ok; card text (detail view, all drawers open) for 3 agencies byte-identical BEFORE vs AFTER at 1280 and 375 px, 0 console errors.
Not done: the file is still pretty-printed (about 0.58 MB of whitespace; `pretty = FALSE` would cut it further but makes the tracked file one line in git diffs). Contract fields repeat per row because `job.R` and the tests require them on the rows.
## Cycle 8 (B2 day basis, branch claude/b2-day-basis)
Chosen: the `days_left` off-by-one and the 71 vs 64 closing-soon gap. `11_build_payload.R` now counts `days_left` from the stamped `PAYLOAD_AS_OF` date (2026-11-07), not REF_DATE (2026-11-06, unchanged). The tool's last hard-coded 14 (deadline-window chip) now uses `CSD`, and the "Closing soon" help text is filled from `closing_soon_days`.
Result: PASS. Payload `days_left` now equals the tool's client-side count for all 631 dated rows; job.R already counted from today. Fact f23 legitimately moved 71 to 64: 7 Top 10 rows close on 2026-11-06, read 0 days left on the old basis, and are closed on the stamped date. facts.csv, fact_sheet row 17 and the real_app_criteria B2 note carry the reason. Tests 89/89, facts 49/49, dupes ok, job.R dry run exit 0. Browser at 1280 and 375 px: the Closing soon tile matches `n_closing_soon` for all 32 agencies, card days match, 0 console errors.
Not done: REF_DATE still fixed (pending human decision). Rebuild needed `10_run_ranking.R` first (local, cached) because items.csv is gitignored; job.R with RUN_PIPELINE=1 also reran the daily refresh, and the payload was rebuilt with 11 afterward.
## Cycle 8 (branch claude/ux-polish)
Chosen: three small UX fixes in `matchmaker.html`. (1) The agency picker button no longer cuts long names with an ellipsis: the name wraps (button at least 44 px tall), the full name is in the button and list-item `title`, and list items are at least 44 px. (2) One label pair, "Pursue" and "Skip": the leftover "pass" wording in the swipe key hint, the "you passed" count, the tight-deadline warnings and the re-sort note now says skip. The internal mark value "Pass" is unchanged, so saved marks and feedback stay compatible. (3) The list-row stub and the swipe card now show the close date next to days left ("Closes Jan 31, 2027"; "Expected" for not-open grants), taken from the listed `close_date` with no new numbers.
Result: PASS on a local server (port 8802, killed after) at 375 and 1280 px with an agency picked: 0 console errors, no sideways scroll, 14-step tour still runs, phone buttons 44 px or more; the origin/main build clipped the same name with an ellipsis at 375 px. Dupes ok; tests 89 of 89.
Not verified: other long agency names beyond the longest (47 characters); screen-reader output; the desktop detail panel was not opened. Tests needed the gitignored `data/processed` files copied from a sibling worktree; nothing tracked changed.
## Cycle 9 (daily as-of date, branch claude/daily-as-of)
Chosen: the human's decision that the daily job's date moves forward so the Top 10 refills as grants expire, without moving `REF_DATE` (it is in the fetch cache keys of 02b and 02e). New `AS_OF_DATE` in `00_config.R` (today in America/New_York, env override, strict YYYY-MM-DD), `PAYLOAD_AS_OF` now follows it (11:00 on that date, so same-day reruns are identical), `SNAPSHOT_AS_OF_DATE` 2026-11-07 for tests. `load_rank_inputs` and `rank_by_agency` take a date (default REF_DATE, so the backtests are untouched); `10_run_ranking.R` and `11_build_payload.R` pass `AS_OF_DATE`; 11 leaves expired posted and notice rows out of Top 10, hidden examples and counts, and stops if items.csv was built for another date; `job.R` sets `AS_OF_DATE` from its own today and keeps its expiry pass as a safety net for shipped files. `check_facts.R` and `run_tests.R` pin the snapshot date.
Result: PASS. Tests 89/89, facts 49/49 after two legitimate changes (f4 488 to 489: one forecast date, 2026-11-06, has now passed; f23 64 to 67: the 7 expired Top 10 rows were replaced and 3 of the refills close within 14 days), dupes ok, `job.R` dry run exit 0. As of 2026-11-07 the new payload differs from the committed one only by 15 expired rows replaced (7 Top 10, 8 hidden), rank shifts behind them and per-agency counts; a same-day rerun is byte-identical. As of 2026-11-20: 120 expired opportunities left out, 57 Top 10 rows replaced, 0 expired rows anywhere, all 32 agencies still at 10, `n_closing_soon` (sum 49) matches the rows. Browser on port 8804 (killed after) at 1280 and 375 px: 0 console errors, no overflow, the Closing soon tile equals `n_closing_soon` for all 32 agencies.
Not done: no new postings are fetched (still a person, `02a` to `03`); the pool of posted grants only shrinks until then. The landing-page "close within 14 days" tile counts unique posted grants with a hard-coded 14, not `n_closing_soon` (40 vs 49 on the 11-20 build); left as it was. check_facts and run_tests need payload.json and items.csv rebuilt for 2026-11-07 after a daily run.

## Cycle 10 (landing closing-soon stat, branch claude/fix-closing-soon-stat)
Chosen: the landing stat "close within 14 days" counted unique posted grants over all payload rows (including hidden and ineligible ones) with a hard-coded 14, so it read 40 while the agency Closing soon tiles summed `n_closing_soon` (49 at 2026-11-20, 67 at 2026-11-07).
Result: PASS. The stat now counts different grants that sit in at least one agency Top 10 (same rule as `n_closing_soon`) within `closing_soon_days`, counted once, and says so: "N different grants in agency Top 10s close within X days" plus a small line "Agency counts add to M" taken from the sum of `n_closing_soon` (shown only when M differs). The two numbers differ by design because a grant can be in several agency Top 10s: 39 vs 67 on the 11-07 payload, 30 vs 49 on a 2026-11-20 payload (old stat: 50 and 40). Also replaced the remaining hard-coded 14 in `matchmaker.html` (Closing soon tile subtitle, stub legend, help text default, fallback) with `CSD`; fact f23 in `facts.csv` now reads `payload$closing_soon_days` instead of 14. Tests 89 of 89, facts 49 of 49, dupes ok. Browser on port 8805 (killed after) at 1280 and 375 px on the 11-07 and 11-20 builds, plus a copy with closing_soon_days set to 7 (labels, tile and legend read 7): 0 console errors from the tool, no horizontal overflow.
Not done: presentation and doc quotes of the old figures (71, 64, 488, 73) were listed in the session report, not edited. The 11-20 payload was built locally and not committed.

## Cycle 11 (public readiness phase 1, branch claude/public-readiness-1)
Chosen: make the repo ready to be public without moving code or data paths. Added LICENSE (Apache-2.0), NOTICE, SECURITY.md, CODE_OF_CONDUCT.md; rewrote README.md for agency staff and CONTRIBUTING.md for outside contributors; untracked 212 internal files (team notes and vault, comms, per-person files, test transcripts, drafts except what 40_label_check.R reads, agent configs, handoff files) after a no-overwrite backup to C:\Code\granthub-internal-backup, and ignored them in .gitignore.
Result: PASS. Tests 89 of 89, facts 49 of 49 (after rebuilding the 2026-11-07 snapshot per the runbook; payload.json unchanged), dupes ok, build_pages.sh builds 73 files, every path the workflows name still exists. Secret scan of the tracked tree found no key patterns; emails and names remain in tracked files (see PR text). Untracking does not remove anything from git history.
Not done: history rewrite, moving files, setting a Pages URL or owner. AI_USAGE_LOG.md and this log stay tracked for the competition disclosure rule; decide later whether they move to a docs folder.
# Researcher Tab, Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "For researchers" tab where a PI pastes an abstract or keywords and gets open federal opportunities ranked by BM25 fit, with mechanism, trial status, budget, deadline, optional filters and a time warning, plus a 20-award test harness.

**Architecture:** R builds a lean `research.json` (open opportunities a university, nonprofit or small business can apply to, with rule-parsed mechanism, trial status and funder code). All matching, filtering and time-warning logic is pure JavaScript in `tool/research/research_core.js` (browser and Node), unit-tested with Node. The tab UI is a separate script loaded lazily by `tool/matchmaker.html`. The NC agency pipeline, payload and tests are not touched.

**Tech Stack:** R 4.5 (readr, dplyr, stringr, jsonlite, tibble), vanilla JS, Node 24 for tests, existing Pages build and CI.

**Spec:** `docs/superpowers/specs/2026-11-09-researcher-tab-design.md`

## Global Constraints

- Phase 1 makes zero third-party requests from the browser. The abstract never leaves the page.
- No win odds, no invented figures. Unresolved fields display "unknown"; never guess a mechanism, trial status or budget.
- Matching is BM25 with k1=1.2, b=0.75 over title (counted twice) plus summary. No embeddings, no language model.
- Lead times: R01 8 weeks, R21 6, K-family 8 (all editable, labelled "estimate"); sign-off 5 business days (editable). Weekends excluded, holidays ignored (say so in the UI).
- Colors only from existing tokens (`--surface-2`, `--text-primary`, `--border`, `--accent`, `--warn-soft`, `--bad-soft`, `--good-soft`). Never `var(--x)` for a name not defined in `:root`. Works in light and dark mode and at 375 px.
- No new R packages. No JS libraries, no CDN. Function names are unique across `tool/` (`python3 app/check_dupes.py` must say ok).
- Every screen with a date or score carries: "Screening aid. Confirm every date and rule on Grants.gov before you act."
- No key or secret in any tracked file. Do not edit `.Renviron`, `.RData`. Log AI use in `AI_USAGE_LOG.md`.
- Existing gates stay green: `Rscript tests/run_tests.R` (89 of 89), `Rscript R/check_facts.R` (49 of 49), `python3 app/check_dupes.py`, `sh app/build_pages.sh`.
- Work on branch `researcher-tab-phase1`; open a PR; merge only after CI passes.

## Review Focus

- Empty, whitespace-only or stopword-only query: no results, a short hint, no error.
- A pasted 5,000-word aims page: finishes in under 2 seconds (only the top 40 query terms by weight are used).
- Forecasted rows with no close date, and posted rows whose close date is today or already past: never "ok" or "late"; a date-less row reads "date not announced" and sorts after dated rows; a past-date row is dropped.
- Filters hide a row only on a known conflict; unknown fields keep the row with an "unknown" badge; zero results names the filter that removed the last rows.
- Abstract text with HTML, `<script>`, Greek letters, "β-amyloid", "T2*-weighted": rendered escaped, tokens "amyloid" and "t2" still match.

---

### Task 1: Parsers and the research payload builder

**Files:**
- Create: `R/helpers_research.R`, `R/14_build_research_payload.R`, `data/manual/nih_ic_codes.csv`, `tests/test_research.R`
- Modify: `tests/run_tests.R` (source and run `tests/test_research.R`, add its checks to `results`)
- Output: `data/processed/research.json`

**Interfaces:**
- Produces (R, in `helpers_research.R`):
  - `parse_mechanism(title: chr) -> chr` activity code or `NA`
  - `parse_trial_status(text: chr) -> chr` one of `"required"`, `"optional"`, `"not_allowed"`, `NA`
  - `parse_hs_flag(text: chr, trial: chr) -> chr` `"trial"`, `"mentioned"` or `NA`
  - `parse_ic(opp_number: chr, funding_activity: chr) -> chr` two-letter NIH IC code or `NA`
  - `build_research_payload(opps: tibble, as_of: Date) -> list(as_of, n, rows)`
- Produces (JSON): `{"as_of":"YYYY-MM-DD","n":N,"rows":[{id,num,title,agency,status,close,floor,ceil,mech,trial,hs,ic,elig,url,sum}]}`; `close`, `floor`, `ceil`, `mech`, `trial`, `hs`, `ic` are `null` when unknown; `elig` is the pipe-joined applicant-type codes; `sum` is the summary cut to 1,200 characters.
- `data/manual/nih_ic_codes.csv`: columns `ic,name`. AA NIAAA, AG NIA, AI NIAID, AR NIAMS, AT NCCIH, CA NCI, DA NIDA, DC NIDCD, DE NIDCR, DK NIDDK, EB NIBIB, ES NIEHS, EY NEI, GM NIGMS, HD NICHD, HG NHGRI, HL NHLBI, LM NLM, MD NIMHD, MH NIMH, NR NINR, NS NINDS, TR NCATS, OD OD.

- [ ] **Step 1: Write the failing tests in `tests/test_research.R`** (same `check(section, name, ok)` style as `run_tests.R`):
  - `parse_mechanism("NIMH BRAINS (R01 Clinical Trial Optional)") == "R01"`
  - `parse_mechanism("... (Collaborative U24 - Clinical Trials not allowed)") == "U24"`
  - `parse_mechanism("... (R43/R44 Clinical Trial Not Allowed)") == "R43"`
  - `is.na(parse_mechanism("Small Business Translator: MedTech and Digital Health Technologies"))`
  - `parse_trial_status` gives `"optional"`, `"not_allowed"` (for both "Clinical Trial Not Allowed" and "Clinical Trials not allowed"), `"required"`; `NA` for "Early- and Late-Stage Clinical Trials for the Spectrum of Alzheimer's Disease"
  - `parse_hs_flag("x", "required") == "trial"`; `parse_hs_flag("involves human subjects", NA) == "mentioned"`; `NA` for neither
  - `parse_ic("RFA-AG-26-020", NA) == "AG"`; `parse_ic("PAR-22-083", "HL") == "HL"`; `is.na(parse_ic("PAR-22-083", NA))`
  - `build_research_payload` on a 5-row toy tibble: excludes a `closed` row, a `notice` row, a row with `applicant_types` only `"00|01"`, a posted row with `close_date` before `as_of`; keeps a forecasted row with `NA` close date (as `null`); duplicates by `opp_id` collapse to one; `sum` length is at most 1,200.
- [ ] **Step 2: Run** `Rscript tests/test_research.R` — expect FAIL (functions not defined).
- [ ] **Step 3: Implement the five functions in `R/helpers_research.R`.** Mechanism: first parenthetical token matching `^(?:Parent |Collaborative )?([A-Z][0-9]{2}|SBIR|STTR)`, else first standalone `\b[RKUPTFDS][0-9]{2}\b`. Pool rule: status `posted` or `forecasted`, and `applicant_types` contains at least one of `06 12 13 20 22 23 25 99`. Missing or empty `applicant_types` is dropped.
- [ ] **Step 4: Implement `R/14_build_research_payload.R`**: sources `00_config.R` and `helpers_research.R`, reads `data/processed/research_opportunities.csv` if it exists, else `data/processed/opportunities.csv`; `as_of = AS_OF_DATE`; writes `data/processed/research.json` with `jsonlite::write_json(auto_unbox = TRUE, na = "null")`; stops if the file exceeds 2,000,000 bytes; prints row count and byte size.
- [ ] **Step 5: Run** `Rscript tests/test_research.R` (all pass), then `Rscript R/14_build_research_payload.R` (expect a row count between 500 and 1,500 and the size line), then `Rscript tests/run_tests.R` (expect "89 of 89" plus the new checks, no failures) and `Rscript R/check_facts.R` ("49 of 49").
- [ ] **Step 6: Commit** on branch `researcher-tab-phase1`: `git add R/helpers_research.R R/14_build_research_payload.R data/manual/nih_ic_codes.csv data/processed/research.json tests/test_research.R tests/run_tests.R && git commit -m "Researcher pool: parsers and research.json builder"`.

---

### Task 2: BM25 core (tokenize, synonyms, index, search)

**Files:**
- Create: `tool/research/research_core.js`, `tool/research/synonyms.json`, `tests/research/test_core.js`
- Test: `node tests/research/test_core.js` (plain `assert`, prints "N tests pass")

**Interfaces:**
- Produces (exported with `module.exports` in Node and `window.ResearchCore` in the browser):
  - `tokenize(text: string) -> string[]` lowercase, split on `/[^\p{L}\p{N}]+/u`, drop stopwords and tokens shorter than 2 characters, strip one trailing `s` from tokens longer than 3 that do not end in `ss`
  - `expandTerms(tokens: string[], groups: string[][]) -> string[]` tokens plus every token (phrases split into tokens) of every group containing any input token
  - `buildIndex(rows: Row[], groups: string[][]) -> Index`
  - `search(index: Index, query: string, opts?: {limit?: number}) -> {id: string, score: number, matched: string[]}[]` descending score, score 0 excluded, default limit 50, uses the top 40 query terms by idf times query frequency
- `synonyms.json`: array of arrays of lowercase strings; at least 30 groups including `["stroke","cerebrovascular","cva","ischemic"]`, `["ct","computed","tomography"]`, `["mri","magnetic","resonance"]`, `["ai","artificial","intelligence","machine","learning","deep"]`, `["cancer","oncology","tumor","neoplasm","carcinoma"]`, `["radiology","imaging","radiologic"]`, `["clinical","patient","bedside"]`, `["alzheimer","dementia","cognitive"]`.

- [ ] **Step 1: Write the failing tests** with a 4-row corpus (ids `a`–`d`: "stroke ct perfusion imaging", "breast cancer screening mammography", "cerebrovascular disease imaging", "grain subsidies"):
  - `tokenize("T2*-weighted β-amyloid <script>x</script>")` contains `"t2"`, `"weighted"`, `"β"` is dropped as shorter than 2, `"amyloid"` present, `"script"` present
  - `tokenize("")` and `tokenize("the and of")` return `[]`
  - `search(idx, "stroke CT")[0].id === "a"`; `"c"` also returned with `matched` including `"cerebrovascular"`; `"d"` absent
  - `search(idx, "")` and `search(idx, "   ")` return `[]`
  - a 6,000-word query over 1,000 generated rows returns within 2,000 ms and has length at most `limit`
  - ordering is deterministic: two calls return identical arrays
- [ ] **Step 2: Run** `node tests/research/test_core.js` — expect FAIL.
- [ ] **Step 3: Implement the four functions** in `research_core.js`: document tokens are title tokens twice plus summary tokens; standard BM25 with `idf = ln(1 + (N - n + 0.5)/(n + 0.5))`; ties broken by row id ascending. Author at least the 30 synonym groups.
- [ ] **Step 4: Run** `node tests/research/test_core.js` — expect all pass.
- [ ] **Step 5: Commit** `git add tool/research tests/research && git commit -m "Researcher tab: BM25 core and synonyms"`.

---

### Task 3: Filters and time warnings

**Files:**
- Modify: `tool/research/research_core.js`, `tests/research/test_core.js`

**Interfaces:**
- Consumes: `Row` shape from Task 1 (`mech`, `trial`, `ceil`, `floor`, `elig`, `close`, `status`).
- Produces:
  - `applyFilters(rows: Row[], profile: Profile) -> {kept: Row[], unknown: Record<string,string[]>, removedBy: Record<string,number>}` where `Profile = {institution?: "university"|"hospital_nonprofit"|"small_business", trial?: "yes"|"no", budgetMin?: number, budgetMax?: number, mechs?: string[], career?: "trainee"|"early"|"established"}`; `unknown[rowId]` lists the filters that could not be evaluated for that row; `removedBy[filter]` counts rows each filter removed
  - `daysUntil(closeIso: string|null, todayIso: string) -> number|null`
  - `businessDaysBefore(isoDate: string, n: number) -> string` weekends skipped, no holidays
  - `timeWarning(row: Row, todayIso: string, settings?: {leadWeeks?: Record<string,number>, signoffBusinessDays?: number}) -> {level: "ok"|"tight"|"late"|"unknown", daysToInstitution: number|null, needDays: number|null, reason: string}`
- Rules: institution maps to codes (`university` 06,20; `hospital_nonprofit` 12,13,25; `small_business` 23) and a row with `99` in `elig` always passes. Trial `"yes"` removes only `trial === "not_allowed"`; `"no"` removes only `"required"`. Budget removes a row only when `ceil` is known and below `budgetMin`, or `floor` is known and above `budgetMax`. Career maps to mechanism families (trainee K, F, T; early R01, R21, R03, R00, K; established everything except K, F, T) and removes only known-mechanism mismatches. Unknown field values keep the row and are recorded in `unknown`.
- `timeWarning`: institutional deadline is `businessDaysBefore(close, signoffBusinessDays)`; `late` if it is before today, `tight` if fewer than `leadWeeks*7` days remain, else `ok`; `unknown` if `close` is null or the mechanism has no lead time (lead time looked up by exact code, then by first letter for K, F, T; default table R01 8, R21 6, K 8).

- [ ] **Step 1: Write the failing tests** (today `"2026-11-09"`, a Monday):
  - `businessDaysBefore("2026-11-20", 5) === "2026-11-13"`; `businessDaysBefore("2026-11-12", 5) === "2026-11-05"`
  - R01 closing `2026-11-20` → `tight`, `daysToInstitution === 4`; R01 closing `2026-11-12` → `late`, `daysToInstitution === -4`; R01 closing `2027-03-01` → `ok`, `daysToInstitution === 105`; `K99` closing `2027-03-01` → `ok` with `needDays === 56`; `R03` → `unknown`; `close: null` → `unknown` with reason "date not announced"; `close === todayIso` → `late`
  - `settings.signoffBusinessDays = 0` changes the first R01 case to `daysToInstitution === 11`
  - Filters: institution `small_business` removes a row with `elig "06|20"` and keeps one with `"23"` and one with `"99"` and one with `""` (listed in `unknown`); trial `"no"` removes `required`, keeps `optional` and `null`; budget `{budgetMin: 500000}` removes `ceil 100000`, keeps `ceil null`; `career: "trainee"` removes mech `R01`, keeps `K99` and `mech null`; `removedBy` counts match; all filters empty returns every row
- [ ] **Step 2: Run** `node tests/research/test_core.js` — expect FAIL on the new tests only.
- [ ] **Step 3: Implement the four functions.** Date math uses UTC dates parsed from `YYYY-MM-DD` only (no local time zone).
- [ ] **Step 4: Run** `node tests/research/test_core.js` — expect all pass.
- [ ] **Step 5: Commit** `git add tool/research tests/research && git commit -m "Researcher tab: filters and time warnings"`.

---

### Task 4: The tab (UI)

**Files:**
- Create: `tool/research/research_tab.js`, `tool/research/research.css`, `tests/research/ui_transparency_check.js`
- Modify: `tool/matchmaker.html` (tab button next to the existing `data-tab` buttons around line 1151, a `<section id="v-research">` wired the same way as `data-tab="how"`, plus `<link>` and lazy `<script>` for the research files), `app/build_pages.sh` (copy `tool/research/*` and `data/processed/research.json` to `$OUT/matchmaker/research/`)

**Interfaces:**
- Consumes: `ResearchCore.search`, `applyFilters`, `timeWarning`, `buildIndex`; `research/research.json`; `research/synonyms.json`.
- Produces: `window.ResearchTab.init(container: HTMLElement)` called once the first time the tab opens; fetches both JSON files with `cache: "no-cache"`, same-origin only.
- `ui_transparency_check.js`: a function expression string for the browser console that returns the list of visible elements inside `#v-research` and the tour popups that have `background-color` alpha 0 and non-empty text; expected result `[]` in both `light` and `dark` `data-theme`.

- [ ] **Step 1: Write `tests/research/ui_transparency_check.js`** (it is the failing check: run it first and expect an error because `#v-research` does not exist).
- [ ] **Step 2: Build the panel.** Layout top to bottom: privacy line ("Your text stays in this browser. Nothing is sent anywhere."), a textarea (label "Paste an abstract, aims, or keywords"), a Search button, three example buttons ("stroke CT perfusion imaging AI", "multimodal AI for radiology reports", "physics-based MRI") that fill the box and search, a collapsed "Filters" disclosure holding the Task 3 profile controls plus editable lead-time and sign-off fields, then a results list. Each card shows title linking to `url`, agency and IC, mechanism badge, trial badge, budget line ("Award ceiling $X as listed" or "Budget: unknown"), deadline line with the `timeWarning` badge (`ok` green, `tight` warn, `late` bad, `unknown` neutral), matched terms highlighted, an "unknown" badge per unresolved filter, and the screening-aid line under the list. A zero-result state names the filter in `removedBy` with the highest count. The results container has `aria-live="polite"`.
- [ ] **Step 3: Escape every inserted string** (`textContent` or an `esc()` helper); never assign untrusted text to `innerHTML`.
- [ ] **Step 4: Update `app/build_pages.sh`** and run `sh app/build_pages.sh "$TEMP/site"`; expect "site built" with the research files counted, and `python3 app/check_dupes.py` ok.
- [ ] **Step 5: Verify in the browser** (serve `$TEMP/site` with `python -m http.server`): at 1280 px and 375 px, in light and dark `data-theme`, search each example and a pasted 500-word abstract. Expected: zero console errors, no horizontal scroll, the transparency check returns `[]`, a close-date warning badge is visible, the Filters disclosure works with the keyboard.
- [ ] **Step 6: Commit** `git add tool app/build_pages.sh && git commit -m "Researcher tab: search-first page"`.

---

### Task 5: The 20-award test set and harness

**Files:**
- Create: `R/15_build_research_testset.R`, `data/research_testset/reporter_sample.json`, `data/research_testset/owner_abstracts.json` (initially `[]`), `tests/research/run_testset.js`

**Interfaces:**
- `R/15_build_research_testset.R` makes one call to the public NIH RePORTER API (`POST https://api.reporter.nih.gov/v2/projects/search`, no key) per topic and writes ten sampled awards (two each: stroke imaging, radiology AI, MRI physics, oncology imaging, general biomedicine; fiscal years 2024 and 2025; `set.seed(20261109)`). Each element: `{id, source: "reporter", project_num, ic, mechanism, title, abstract, topic}`; `ic` is the two-letter code mapped from `AgencyIcAdmin` through `nih_ic_codes.csv`; awards whose IC or activity code is missing are skipped.
- `owner_abstracts.json` rows use the same fields with `source: "owner"`.
- `run_testset.js` loads `data/processed/research.json`, both test files and `synonyms.json`; for each abstract it runs `search(...)` and reports the rank of the first result with the same `ic` and the first with the same `mech` (`null` if none or if the row IC is unknown), then writes `outs/research_testset_report.csv` and prints: awards run, hits within top 10 for IC, for mechanism and for both, the share of pool rows with a known IC and known mechanism, and a random baseline (mean of `1-(1-p)^10` for each abstract's IC and mechanism share `p`). It sets no pass bar and exits 0.

- [ ] **Step 1: Write the failing check**: `node tests/research/run_testset.js` on an empty sample prints "0 awards" and exits 0; with one hand-made fixture whose IC is in the pool it prints one hit. Add both cases to `tests/research/test_core.js` using an exported pure function `scoreTestset(rows, awards, groups)`.
- [ ] **Step 2: Run** `node tests/research/test_core.js` — expect FAIL.
- [ ] **Step 3: Implement `scoreTestset` in `run_testset.js`** (exported, with the CLI wrapper under `require.main === module`).
- [ ] **Step 4: Run `Rscript R/15_build_research_testset.R`.** This is an outside-service call to a public API with no key; run it once and commit the output (do not re-run it casually). Expect 10 awards written; read the file and drop any award whose abstract is empty.
- [ ] **Step 5: Run** `node tests/research/test_core.js` (pass) and `node tests/research/run_testset.js`; copy the printed summary into `docs/research_testset_results.md` as "first run, no bar set".
- [ ] **Step 6: Commit** `git add R/15_build_research_testset.R data/research_testset tests/research docs/research_testset_results.md && git commit -m "Researcher tab: 20-award test set and harness"`.

---

### Task 6: CI, docs and the pool refresh script

**Files:**
- Modify: `.github/workflows/checks.yml` (node tests step), `README.md`, `docs/runbook.md`, `docs/REPO_MAP.md`, `AI_USAGE_LOG.md`
- Create: `R/02f_research_pool.R`

**Interfaces:**
- `R/02f_research_pool.R` reads `SIMPLER_GRANTS_KEY` from the environment, pages the Simpler.Grants.gov search for `posted` and `forecasted` opportunities with no agency or eligibility filter, caches with keys `simpler_research_<AS_OF_DATE>_p<n>` (not `REF_DATE`, so the NC cache and snapshot are untouched), and writes `data/processed/research_opportunities.csv` with the same columns as `opportunities.csv` that Task 1 reads. It is a deliberate copy of the paging in `02e`, so the NC pipeline and its pinned tests stay unchanged.

- [ ] **Step 1: Add to `checks.yml`** a step `node tests/research/test_core.js` and a step `node tests/research/run_testset.js`.
- [ ] **Step 2: Document**: README section "For researchers" (what it does, the screening-aid limit, that unknown means unknown, how to run `node tests/research/test_core.js`), runbook lines for `R/14_build_research_payload.R` and the optional refresh, REPO_MAP rows for the new paths, one `AI_USAGE_LOG.md` row for this work. State in the README that phase 1 sends nothing to third parties.
- [ ] **Step 3: Write `R/02f_research_pool.R` but do not run it.** Running it needs the owner's Simpler.Grants.gov key copied into an untracked `api_keys.env` at the repo root and the owner's go-ahead; with the key, run it, then `Rscript R/14_build_research_payload.R`, `node tests/research/run_testset.js`, and compare the pool size and the test-set summary against the first run in `docs/research_testset_results.md`.
- [ ] **Step 4: Run the full gate locally**: `Rscript tests/run_tests.R`, `Rscript R/check_facts.R`, `python3 app/check_dupes.py`, `node tests/research/test_core.js`, `sh app/build_pages.sh "$TEMP/site"`. Expect: 89 plus new checks pass, 49 of 49, ok, all pass, site built.
- [ ] **Step 5: Push the branch and open a PR** titled "Researcher tab, phase 1"; wait for the Checks workflow to pass before merging.

---

## Self-review

- **Spec coverage:** pool and parsing (Task 1), BM25 with matched terms and synonyms (2), filters and time warnings (3), search-first page with examples, privacy line, screening-aid wording (4), 20-award test set with no bar (5), CI, docs, optional re-fetch (6). Animals and human-subjects filters are not built in phase 1: no rule-derived field exists for animals, and the human-subjects flag is shown on the card only; the trial filter covers the derivable part. Multi-cycle NIH dates are out of scope (spec).
- **Type consistency:** `Row` fields (`id num title agency status close floor ceil mech trial hs ic elig url sum`) are the same in Tasks 1, 3, 4 and 5; `applyFilters`, `timeWarning`, `search`, `scoreTestset` signatures match where they are consumed.
- **Proportion:** the plan holds signatures, assertions and commands; the only bodies given are rules the signatures do not determine (pool filter, lead times, date math).

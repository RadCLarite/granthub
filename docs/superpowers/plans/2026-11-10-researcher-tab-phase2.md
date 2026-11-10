# Researcher Tab, Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the "For researchers" tab with (1) an opt-in ORCID lookup that fills the search box from the researcher's own papers, (2) a foundation funding list searched with the same engine, (3) calendar and Atom feeds, and (4) per-card unusual-case flags with a "my project has..." checklist.

**Architecture:** R builds the new data (`flags` and `post` on each `research.json` row, `research_foundations.json` from a hand-authored CSV). All logic stays pure JavaScript in `tool/research/research_core.js` (flag notes, ICS text, ORCID checks, OpenAlex URL and abstract rebuilding, foundation search) with tab wiring in `research_tab.js`. The only third-party request is one click-triggered `GET` to `api.openalex.org`; the ORCID iD is the only data sent. Feeds are static files from `app/build_feeds.py` plus a browser-built `.ics` of the visible results.

**Tech Stack:** R 4.5 (existing packages only), vanilla JS, Python 3 stdlib (feeds), Node 24 for tests, existing Pages build and CI.

**Spec:** `docs/superpowers/specs/2026-11-09-researcher-tab-design.md` (Scope and Phases, item 2). Phase 1 plan: `docs/superpowers/plans/2026-11-09-researcher-tab-phase1.md`.

## Global Constraints

- Phase 2 adds exactly one third-party host: `https://api.openalex.org`. No request fires until the user clicks "Look up my papers" after reading the visible notice. Nothing is stored (no cookie, localStorage or log). No other host, no library, no CDN.
- No key or secret in any tracked file. OpenAlex runs without a key (see Review Focus 1). Do not edit `.Renviron`, `.RData`.
- No win odds, no invented figures. A flag, date or amount that the source does not state shows "unknown"; never guess. Foundation rows without a source URL and `verified_on` date are rejected by the validator, not displayed.
- Matching stays BM25 (k1=1.2, b=0.75), no embeddings. Foundations reuse `buildIndex` and `search`, never a second ranking method.
- Every screen with a date or score keeps: "Screening aid. Confirm every date and rule on Grants.gov before you act." Foundation cards say "Confirm on the foundation's own page."
- Colors only from existing tokens (`--surface-2`, `--text-primary`, `--border`, `--accent`, `--warn-soft`, `--bad-soft`, `--good-soft`). Works in light and dark mode and at 375 px. Function names unique across `tool/` (`python3 app/check_dupes.py` must say ok).
- Existing gates stay green: `Rscript tests/run_tests.R`, `Rscript R/check_facts.R`, `node tests/research/test_core.js`, `node tests/research/run_testset.js`, `python3 app/check_dupes.py`, `sh app/build_pages.sh`. The test-set hit counts must not drop.
- Do not run `R/02f_research_pool.R` or any outside-service script without the owner's go-ahead. `data/processed/research.json` is rebuilt from the existing cached `opportunities.csv` only.
- Log AI use in `AI_USAGE_LOG.md`. Work on branch `researcher-phase2`; open a PR; merge only after CI passes.

## Decisions made in this plan (owner can overrule at review)

1. **ORCID resolved by OpenAlex alone.** One OpenAlex request (`authorships.author.orcid` filter) returns titles, years and abstracts. The ORCID API adds a second host and no extra matching text, so it is not called. The ORCID iD is still the input, checksum-validated locally.
2. **Pasted publication list needs no new control.** The existing box already takes it. Task 5 adds `cleanPublicationList` so reference numbers and DOI strings do not become query terms.
3. **Feeds are per NIH institute plus one "all open" feed, and a browser `.ics` of the user's current results.** A static site cannot run a per-person query, so the personal calendar is built in the browser; the static feeds serve groups (a lab manager can subscribe to "NCI").
4. **Flags come from the full text in R, not the 1,200-character summary.** `opportunities.csv` has full `summary`, `eligibility_text` and a structured `cost_sharing` column; most flags will still be "unknown", and the card says so.
5. **Foundation rows are data, not code.** The plan builds schema, validator, loader and display. The seed rows are a sourced research step (Task 3, Step 6) with each row's own page as source; any row that cannot be sourced is left out.

## Review Focus

1. OpenAlex limits: without a key, requests share a free daily budget per IP (observed 2026-11-10: $0.10/day, about $0.0001 per request). A 429, a network error, a 10-second timeout, zero works and works with no abstract must each show a plain message and leave the box untouched.
2. ORCID iD typed with spaces, a URL prefix, lower-case `x`, or a bad checksum: normalised or rejected locally with no request sent.
3. Flag false positives: "IND" inside "behind" or "individual", "foreign" in "foreign-born" population text, "animal" in "animal-assisted". Flags use whole-word, case-aware patterns and are labelled "mentioned", never "required".
4. A foundation row older than 365 days or missing a source: stale rows show a stale badge; rows missing `url` or `verified_on` fail the validator and the build.
5. Feeds and calendar: titles with `&`, `<`, commas and semicolons; rows with no close date are skipped in `.ics`, not given a made-up date; zero results offers no download.

---

### Task 1: Opportunity flags and posted date in the payload (R)

**Files:**
- Modify: `R/helpers_research.R` (add `parse_flags`, extend `build_research_payload`), `tests/test_research.R`
- Output: `data/processed/research.json` (rebuilt from cached data)

**Interfaces:**
- Produces: `parse_flags(summary: chr, eligibility: chr, cost_sharing: chr) -> list` of named lists, one per input row. Keys (only those not unknown are present): `cost_share`, `foreign`, `subaward`, `multi_pi`, `ind_ide`, `data_sharing`, `animals`, `human_subjects`, `loi`. Values: `"yes"` (the text names it) or `"no"` (only `cost_share`, from the structured column value `No`).
- Produces (JSON): each row gains `flags` (object, `{}` when none) and `post` (`YYYY-MM-DD` or `null`, from `post_date`).

- [ ] **Step 1: Write failing tests** in `tests/test_research.R`:
  - `parse_flags("Letter of intent due 2026-12-01", "", "")[[1]]$loi == "yes"`
  - `parse_flags("", "", "Yes")[[1]]$cost_share == "yes"`; with `"No"` gives `"no"`; with `NA` the key is absent
  - `"Applicants must include a foreign component"` sets `foreign`; `"foreign-born residents"` does not
  - `"Investigational New Drug (IND) application"` and `"IDE"` (standalone, upper case) set `ind_ide`; `"individual investigators behind the study"` does not
  - `"data sharing plan"` and `"Data Management and Sharing"` set `data_sharing`; `"animal models"` sets `animals`; `"human subjects"` sets `human_subjects`; `"multiple principal investigators"` and `"multi-PI"` set `multi_pi`; `"subaward"` and `"subaward/subcontract"` set `subaward`
  - empty and `NA` text give `list()`
  - `build_research_payload` on a two-row fixture emits `flags` and `post` for each row, with `post` null when `post_date` is `NA`
- [ ] **Step 2: Run** `Rscript tests/run_tests.R`. Expected: the new checks FAIL (`parse_flags` not found).
- [ ] **Step 3: Implement `parse_flags`** with `stringr` patterns over `paste(summary, eligibility)`; patterns are case-insensitive except `IND`/`IDE`, which need `\b(IND|IDE)\b` case-sensitive. Add `flags` and `post` in `build_research_payload`; payload stays at most 20% larger than before (`flags` objects are small; check with `file.size`).
- [ ] **Step 4: Run** `Rscript tests/run_tests.R` and `Rscript R/14_build_research_payload.R`. Expected: all checks pass; `research.json` rows have `flags`.
- [ ] **Step 5: Commit** `git add R tests data/processed/research.json && git commit -m "feat: parse unusual-case flags and posted date into research.json"`

### Task 2: Flag notes and the "my project has" checklist (JS)

**Files:**
- Modify: `tool/research/research_core.js`, `tool/research/research_tab.js`, `tool/research/research.css`, `tests/research/test_core.js`

**Interfaces:**
- Consumes: Task 1 row field `flags`.
- Produces (core, exported): `FLAG_LABELS: { [key]: string }` for the nine keys; `flagNotes(row, ticked: string[]) -> { shown: {key,label,state}[], unknownTicked: {key,label}[] }`. `shown` lists every key present in `row.flags` (`state` is `"yes"` or `"no"`), flags the user ticked first. `unknownTicked` lists ticked keys absent from `row.flags`.

- [ ] **Step 1: Write failing tests**: `flagNotes({flags:{foreign:'yes',loi:'yes'}}, ['loi'])` puts `loi` first in `shown` and has empty `unknownTicked`; `flagNotes({flags:{}}, ['ind_ide'])` returns empty `shown` and `unknownTicked` of one item labelled with `FLAG_LABELS.ind_ide`; a missing or `null` `flags` behaves as `{}`; `FLAG_LABELS` has exactly the nine keys; label text for `yes` never contains "required" (assert on every label).
- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL (`flagNotes is not a function`).
- [ ] **Step 3: Implement `flagNotes` and `FLAG_LABELS`** in `research_core.js`. Labels read "Notice mentions: letter of intent" style; `unknownTicked` text on the card is "You ticked X. This listing does not say. Read the notice."
- [ ] **Step 4: Wire the tab**: a collapsible "My project has..." group of nine checkboxes inside Filters (no filtering, highlight only); `buildCard` renders `shown` as small badges and `unknownTicked` as one muted line. Escape all text through the existing `el()` helper.
- [ ] **Step 5: Run** `node tests/research/test_core.js` and `node tests/research/run_testset.js`. Expected: all pass; hit counts equal the pre-change run. Check in the browser at desktop and 375 px, light and dark.
- [ ] **Step 6: Commit** `git commit -m "feat: show unusual-case flags and a project checklist on research cards"`

### Task 3: Foundation list: schema, validator, payload (R) and display (JS)

**Files:**
- Create: `data/manual/foundations.csv`, `R/15_build_foundations.R`, `tests/test_foundations.R`
- Modify: `tests/run_tests.R`, `tool/research/research_core.js`, `tool/research/research_tab.js`, `app/build_pages.sh`, `tests/research/test_core.js`
- Output: `data/processed/research_foundations.json`

**Interfaces:**
- CSV columns: `id,name,focus,career_stage,award_note,url,verified_on` (`focus` is the foundation's own one-sentence description of what it funds, used as the search text; `award_note` quotes amount and deadline wording from the page, or is empty).
- Produces (R): `validate_foundations(df: tibble, as_of: Date) -> character()` of error messages (empty when valid); rules: every field except `career_stage` and `award_note` non-empty, `url` starts `https://`, `verified_on` parses as a date not after `as_of`, `id` unique.
- Produces (JSON): `{"as_of","n","rows":[{id,name,focus,career,note,url,verified}]}`.
- Produces (core): `foundationStale(verified: string, today: string, maxDays = 365) -> boolean`; `buildFoundationIndex(rows, groups)` and `searchFoundations(index, query, opts)` as thin wrappers over `buildIndex` and `search` using `focus` as the summary and `name` as the title.

- [ ] **Step 1: Write failing tests**: R: `validate_foundations` returns an error for a missing `url`, an `http://` url, an unparseable or future `verified_on`, and a duplicate `id`, and `character(0)` for a valid row; `Rscript R/15_build_foundations.R` stops with those messages on a bad CSV (test via a temp file). JS: `foundationStale('2025-01-01','2026-11-10') === true`, `foundationStale('2026-06-01','2026-11-10') === false`, `foundationStale('', '2026-11-10') === true`; `searchFoundations` over two fixture rows ranks the row whose focus matches the query first and returns `[]` for stopword-only text.
- [ ] **Step 2: Run** both suites. Expected: FAIL (functions and script missing).
- [ ] **Step 3: Implement** the validator and builder (fail the build on any error), the three core functions, and the tab section: below federal results, a heading "Foundations" listing up to 10 matches with name linked to `url`, focus text, `award_note` when present, "Verified on {date}" and a "Stale: check the page" badge when `foundationStale`. Empty list shows nothing (no heading). `build_pages.sh` copies `research_foundations.json` to `matchmaker/research/` and fails if absent.
- [ ] **Step 4: Run** both suites with a two-row fixture CSV committed as the seed. Expected: pass.
- [ ] **Step 5: Commit** `git commit -m "feat: foundation list schema, validator, payload and tab section"`
- [ ] **Step 6: Seed the real list (research step, separate commit).** For each foundation on a broad biomedical shortlist the owner approves at review, read the foundation's own funding page and fill `focus`, `career_stage`, `award_note` and `url` from it, with today's date as `verified_on`. A foundation whose page cannot be read or does not state what it funds is skipped and listed in the PR body. Do not fill any field from memory. Commit `data/manual/foundations.csv` and the rebuilt JSON as `data: seed foundation list (sourced, verified 2026-11-10)`.

### Task 4: Static feeds per institute (Python)

**Files:**
- Modify: `app/build_feeds.py`, `.github/workflows/checks.yml` (extend the existing feed check to `feeds/research/`)
- Test: `tests/research/test_feeds.py`

**Interfaces:**
- Consumes: `data/processed/research.json` rows (`id,title,ic,close,url,num,post,status`).
- Produces: `<out>/feeds/research/<ic>.atom`, `<ic>.ics` for every IC with at least one posted row, plus `all.atom` and `all.ics`; an index section on `feeds/index.html`. A new third CLI argument (optional) is the research payload path; without it the script behaves as today.

- [ ] **Step 1: Write failing test** `tests/research/test_feeds.py` (stdlib `unittest`, runs the script on a three-row fixture): one row with `&` and `<` in the title, one with `close: null`, one forecasted. Assert: every `.atom` parses with `xml.dom.minidom`; the `&` title appears escaped; the null-close row is in the Atom feed and absent from the `.ics`; the forecasted row is in neither; each `.ics` starts `BEGIN:VCALENDAR` and ends `END:VCALENDAR`; commas and semicolons in titles are backslash-escaped; a run without the research argument creates no `research/` folder.
- [ ] **Step 2: Run** `python3 -m unittest tests/research/test_feeds.py`. Expected: FAIL (no research output).
- [ ] **Step 3: Implement** in `build_feeds.py`, reusing its `x()` and `ics_text()` helpers; Atom entries ordered by close date (dated first), summary line "{num}. Closes {date or 'no close date listed'}. Screening aid; confirm on Grants.gov."; `build_pages.sh` passes the research payload as the third argument.
- [ ] **Step 4: Run** the unit test, `sh app/build_pages.sh` and the CI feed check snippet locally. Expected: pass; `feeds/research/` exists in the built site.
- [ ] **Step 5: Commit** `git commit -m "feat: static Atom and calendar feeds per NIH institute"`

### Task 5: Browser calendar export and publication-list cleanup (JS)

**Files:**
- Modify: `tool/research/research_core.js`, `tool/research/research_tab.js`, `tests/research/test_core.js`

**Interfaces:**
- Produces (core, exported): `buildIcs(rows: {id,title,close,url,num}[], stamp: string) -> string` (RFC 5545 text, CRLF line ends, one all-day `VEVENT` per row with a `close` date, rows without one skipped; `stamp` is `YYYYMMDDTHHMMSSZ`, passed in so the function is pure); `cleanPublicationList(text: string) -> string`.

- [ ] **Step 1: Write failing tests**: `buildIcs` for two rows (one with a title containing `, ; &`, one with `close: null`) yields exactly one `VEVENT`, `DTSTART;VALUE=DATE:20261201`, `DTEND;VALUE=DATE:20261202`, escaped title, `UID` containing the row id, CRLF endings, starts `BEGIN:VCALENDAR`; a month-end close (`2026-12-31`) ends `20270101`; zero dated rows returns `''`. `cleanPublicationList('1. Smith J, et al. Deep learning for stroke. Radiology 2024. doi:10.1148/radiol.1234\n[2] Lee K. Perfusion CT.')` removes the leading `1.` and `[2]`, the `doi:` token and the DOI string, and keeps the title words.
- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL.
- [ ] **Step 3: Implement both**; month rollover through `Date.UTC` arithmetic, not string math. Tab: a "Add these deadlines to my calendar (.ics)" button under the result list, built from `kept` rows with a close date, saved through a `Blob` download named `grant-deadlines.ics`; hidden when no row has a close date. Apply `cleanPublicationList` to the box text only when the user clicks a small "Clean pasted list" link (never silently).
- [ ] **Step 4: Run** unit tests; in the browser open the downloaded file text and check dates against the cards.
- [ ] **Step 5: Commit** `git commit -m "feat: calendar download of result deadlines; publication list cleanup"`

### Task 6: ORCID and OpenAlex lookup (JS)

**Files:**
- Modify: `tool/research/research_core.js`, `tool/research/research_tab.js`, `tool/research/research.css`, `tests/research/test_core.js`

**Interfaces:**
- Produces (core, exported):
  - `normalizeOrcid(raw: string) -> string | null` returns `0000-0002-1825-0097` form for input with optional `https://orcid.org/` prefix, spaces or hyphens omitted, upper-case `X`; `null` unless 16 chars and the ISO 7064 mod 11-2 check digit is correct (total = (total + digit) * 2 over the first 15 digits; check = (12 - total % 11) % 11, 10 written `X`).
  - `openAlexWorksUrl(orcid: string, perPage = 25) -> string` giving `https://api.openalex.org/works?filter=authorships.author.orcid:https://orcid.org/<id>&sort=publication_year:desc&per-page=<n>&select=title,publication_year,abstract_inverted_index,topics`.
  - `worksToText(works: object[], maxChars = 3000) -> string`: for each work, title, then the abstract rebuilt from `abstract_inverted_index` (words placed by position), then up to 2 topic `display_name`s; works joined by newlines; works with neither title nor abstract skipped; output cut at `maxChars` on a word boundary.

- [ ] **Step 1: Write failing tests**: `normalizeOrcid('0000-0002-1825-0097')`, `'https://orcid.org/0000-0002-1825-0097'`, `' 0000 0002 1825 0097 '` all return `0000-0002-1825-0097`; `'0000-0002-1694-233x'` returns `0000-0002-1694-233X`; a one-digit change (`0000-0002-1825-0098`), a short string, letters and `null` input return `null`. `openAlexWorksUrl` equals the exact string above for the example iD and contains no other host. `worksToText([{title:'A', abstract_inverted_index:{Deep:[0],learning:[1],helps:[2]}, topics:[{display_name:'Stroke'}]}])` returns `'A Deep learning helps Stroke'` modulo whitespace; a work with `abstract_inverted_index: null` still yields its title; `worksToText([])` returns `''`; a 10,000-word input is no longer than 3,000 characters and does not cut a word.
- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL.
- [ ] **Step 3: Implement the three functions** as specified.
- [ ] **Step 4: Wire the tab.** Above the box, a collapsed "Use my ORCID" block with this visible notice: "Clicking Look up sends only your ORCID iD to OpenAlex (api.openalex.org) and reads your public papers. Nothing is stored. Your pasted text never leaves this page." Input, then a "Look up my papers" button. On click: `normalizeOrcid`, show "That iD does not look right" and stop if `null`; otherwise `fetch` with `AbortController` (10 s) and `credentials: 'omit'`; on success put `worksToText(results)` in the box (never overwriting non-empty text without a confirm) and show "Filled from N papers. Edit the text, then press Search." Messages for 429 ("OpenAlex is busy or the free daily limit is used up. Paste your abstract instead."), timeout, network error and zero works (all plain, none touching the box). The button is disabled while a request runs.
- [ ] **Step 5: Run** unit tests. Browser check against the real API with the public example iD `0000-0002-1825-0097` (an ORCID documentation sample iD, not a real person's data): box fills, search runs; then with the network blocked and with a bad iD. Expected: each message appears; no request leaves for a bad iD (confirm in the network panel).
- [ ] **Step 6: Commit** `git commit -m "feat: opt-in ORCID lookup through OpenAlex"`

### Task 7: Docs, CI and wrap-up

**Files:**
- Modify: `README.md`, `docs/research_testset_results.md` (rerun note), `AI_USAGE_LOG.md`, `.github/workflows/checks.yml` (add `python3 -m unittest tests/research/test_feeds.py`), `docs/PUBLISHING_CHECKLIST.md` (add the OpenAlex host and the no-key stance)

- [ ] **Step 1: Document** the one third-party host, the notice text, the daily budget behaviour and what to do if the owner later gets a key (a key in a public static page is visible to everyone, so use it only through a proxy the owner controls; do not commit it).
- [ ] **Step 2: Run the full gate list** from Global Constraints plus `python3 -m unittest tests/research/test_feeds.py`. Expected: all pass; test-set hit counts unchanged.
- [ ] **Step 3: Browser pass** on the built site (`sh app/build_pages.sh`, serve the output): ORCID lookup, quoted phrase still filters, flags and checklist, foundations section, `.ics` download, feeds index. Desktop and 375 px, light and dark.
- [ ] **Step 4: Log AI use, commit** `git commit -m "docs: phase 2 notes, CI feed test, publishing checklist"`; open the PR. In the PR body list skipped foundations, the OpenAlex limit, and that the human validation in phase 3 is not done.

---

## Self-review notes

- Spec coverage: ORCID and OpenAlex (Tasks 5 and 6), foundation list with source URL and verified-on date (Task 3), calendar and RSS feeds (Tasks 4 and 5), unusual-case checklist covering trial (existing `trial` field), foreign, multi-PI, subaward, cost share, IND/IDE, data sharing, animals or human subjects, letter of intent (Tasks 1 and 2).
- Not in this plan: human validation (phase 3), email alerts, accounts, embeddings.
- Names used across tasks: `flags`, `post`, `flagNotes`, `FLAG_LABELS`, `foundationStale`, `searchFoundations`, `buildIcs`, `cleanPublicationList`, `normalizeOrcid`, `openAlexWorksUrl`, `worksToText`.

# Researcher tab: phrase handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a researcher put a phrase in double quotes to require it, and rank results higher when the query's words appear next to each other in the same order.

**Architecture:** `research_core.js` keeps each indexed row's token sequences (title and summary) next to the existing BM25 counts. A new `parseQuery` pulls quoted phrases out of the query; `search` drops rows that lack any phrase (hard filter) and adds a small per-bigram boost to the BM25 score of rows that remain. The tab shows which phrases are active and explains an empty result. The test-set harness gains one flag so the boost can be compared against no boost.

**Tech Stack:** Plain JavaScript (UMD module, no dependencies), Node assert tests, the existing `tests/research/run_testset.js` harness.

**Spec:** `docs/superpowers/specs/2026-11-09-researcher-tab-design.md` (matching section: "local BM25 with a biomedical synonym list; matched terms shown"). The spec is silent on phrases. The decisions below were made in this session on 2026-11-09 and are the binding text for this plan.

## Decisions (this plan's mini-spec)

- **Quoted phrase = hard filter.** A row stays only if the phrase's tokens appear consecutively, in order, in its title or in its summary (not straddling the two). Several phrases are ANDed.
- **Matching is on tokens, not raw text.** The existing tokenizer is unchanged, so lowercase, stop words dropped, trailing "s" stripped. "stroke of the brain" and "stroke brain" are the same phrase. Phrase words are not synonym-expanded; the rest of the query still is.
- **Quotes count only in short queries.** Quote marks are read as phrase markers only when the raw query is at most 200 characters (`PHRASE_QUERY_MAX_CHARS`). The same box takes pasted abstracts, and 1 of the 10 RePORTER sample abstracts contains quote characters; a scare quote in an abstract must not become a filter. Over 200 characters, quote marks are plain punctuation.
- **Adjacent-word boost.** For every distinct bigram (two consecutive tokens, in query order) found consecutively in a row's title or summary, add `PHRASE_BOOST * (idf(w1) + idf(w2)) / 2` to that row's score. `PHRASE_BOOST = 0.5`, fixed in advance. It is not tuned on the test set (10 awards would overfit). The boost never adds a row; it only reorders rows BM25 already scored.
- **Bigrams bridge removed stop words** ("perfusion of the CT" has the bigram perfusion+ct) because adjacency is judged on the token sequence the tokenizer returns.
- **Ship rule for the boost** (set before any run): keep `PHRASE_BOOST = 0.5` as the default only if, on the awards present, IC hits, mechanism hits and both-hits are each at least the no-boost baseline. If any drops, set the default to 0 (code stays, opt-in through `opts.phraseBoost`) and say so in the results doc.
- **Out of scope:** OR/NOT/wildcard operators, proximity ("within 5 words"), phrase synonyms, a bigram index, highlighting a phrase as one unit, phrase terms in the research payload.

## What the test set can and cannot show

- Only **10 of the 20 awards exist**. The 10 owner abstracts are still missing (`data/research_testset/owner_abstracts.json` is `[]`). Task 4 runs on whatever exists and states the count. Do not call it a 20-award result unless 20 awards were run. One award is 10 percentage points, so this run can show "no regression", not "improvement".
- The harness queries with full abstracts (2,400 to 3,300 characters), so the 200-character rule means it **never exercises quoted phrases**. The hard filter is covered by unit tests only. The harness measures the boost.
- The harness metric is a proxy (same funder and same mechanism in the top 10), not topical relevance.

## Global Constraints

- No dependencies; `research_core.js` stays UMD (`module.exports` in Node, `window.ResearchCore` in the browser).
- `tokenize`, `expandTerms`, `tool/research/synonyms.json` and the `search` result shape (`{ id, score, matched }`, sorted by score descending then id ascending) do not change.
- Same input gives identical output: deterministic, ties by id ascending.
- All text shown by the tab goes through `textContent` (the existing `el()` helper); never `innerHTML`.
- Nothing typed leaves the browser; no new network request.
- Tests run with `node tests/research/test_core.js` (CI already runs it) and `node tests/research/run_testset.js`.
- Branch off up-to-date `main` as `researcher-phrases`. Commit messages end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Open a PR, merge only after CI passes. Do not edit `.Renviron`, `.RData` or any key file; do not run outside-service scripts.
- Log the AI use in `AI_USAGE_LOG.md` (Task 4).

## Review Focus

1. **A pasted abstract that contains quote marks** must not be filtered by them. Expected: over 200 characters, quotes are ignored. Test in Task 1.
2. **A quoted phrase that matches nothing** must say so, not fall through to the generic "shares words" message. Expected: `search` returns `[]` with the filter and hits with `phraseFilter: false`; the tab then says no open opportunity contains that exact phrase and how to search the words separately. Test in Task 1 (core) and Task 3 (tab).
3. **Malformed quotes**: an unbalanced `"ct perfusion`, empty `""`, a phrase of only stop words `"the of"`, curly quotes `“ct perfusion”`, more than 5 phrases. Expected: unbalanced, empty and stop-word-only phrases are ignored (words still searched), curly quotes work like straight ones, the 6th and later phrases are plain text. Test in Task 1.
4. **Stop words and plurals inside a phrase.** Expected: `"stroke brain tumor"` matches a title "Stroke of the brain tumors". Test in Task 1.
5. **A phrase that straddles the title and summary** (title ends "CT", summary starts "perfusion") must not match. Expected: no match. Test in Task 1.

---

### Task 1: parseQuery and the quoted-phrase hard filter

**Files:**
- Modify: `tool/research/research_core.js` (`buildIndex`, `search`, exports)
- Test: `tests/research/test_core.js`

**Interfaces:**
- Consumes: existing `tokenize(text) -> string[]`, `buildIndex(rows, groups)`, `search(index, query, opts)`.
- Produces:
  - `parseQuery(raw: string) -> { plain: string, phrases: Array<{ text: string, tokens: string[] }> }`. `plain` is `raw` with each quote character (`"`, `“`, `”`) replaced by a space. `phrases` holds balanced quoted segments of a raw query of at most 200 characters, in order, deduplicated by `tokens.join(' ')`, only those with at least one token, at most 5 (the rest stay plain text).
  - `buildIndex` docs gain `seq: string[][]` = `[titleTokens, summaryTokens]`.
  - `search(index, query, opts)` gains `opts.phraseFilter` (boolean, default `true`). Exported: `parseQuery`.

- [ ] **Step 1: Write the failing tests** in `tests/research/test_core.js`, in the file's `t(name, fn)` style, using a fixture index `pidx = RC.buildIndex(prows, groups)`:

```js
const prows = [
  { id: 'p1', title: 'CT perfusion imaging in acute stroke', sum: '' },
  { id: 'p2', title: 'Perfusion of the heart; CT of the lung', sum: '' },
  { id: 'p3', title: 'Stroke outcomes', sum: 'Advanced CT perfusion protocols' },
  { id: 'p4', title: 'Stroke of the brain tumors', sum: '' },
  { id: 'p5', title: 'Lung CT', sum: 'perfusion study' },
];
```

Tests (names and assertions):
- `parseQuery basics`: `parseQuery('"CT perfusion" stroke')` → `plain` equals `' CT perfusion  stroke'`, `phrases` deep-equals `[{ text: 'CT perfusion', tokens: ['ct','perfusion'] }]`; curly `“ct perfusion”` gives the same tokens.
- `parseQuery malformed`: `'"ct perfusion'` → `phrases` is `[]` and `plain` tokenizes to `['ct','perfusion']`; `'""'` and `'"the of"'` → `phrases` `[]`; `'"a1 b1" "a1 b1"'` → 1 phrase (deduped); six distinct quoted phrases → `phrases.length === 5`.
- `parseQuery long query ignores quotes`: `'word '.repeat(60) + '"ct perfusion"'` (over 200 characters) → `phrases` `[]`.
- `phrase filter`: `RC.search(pidx, '"ct perfusion"').map(r => r.id).sort()` equals `['p1','p3']`; the same query with `{ phraseFilter: false }` includes `'p2'`.
- `phrase filter keeps ranking order`: with `{ phraseBoost: 0 }`, `search(pidx, '"ct perfusion" stroke')` ids equal `search(pidx, 'ct perfusion stroke', { phraseBoost: 0 })` ids with `p2`, `p4`, `p5` removed (relative order preserved).
- `phrase stop words and plurals`: `search(pidx, '"stroke brain tumor"')` ids `['p4']`; `'"stroke tumors"'` returns `[]`.
- `phrase does not straddle title and summary`: `search(pidx, '"ct perfusion"')` does not include `p5`.
- `two phrases are ANDed`: `'"ct perfusion" "acute stroke"'` returns only `['p1']`.
- `single-word phrase`: `search(pidx, '"perfusion"')` ids sorted equal `['p1','p2','p3','p5']`.

- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL (`parseQuery is not a function` or a wrong id list).

- [ ] **Step 3: Implement** `parseQuery` and `PHRASE_QUERY_MAX_CHARS = 200`, `MAX_PHRASES = 5` in `research_core.js`; store `seq` on each doc in `buildIndex`; in `search`, call `parseQuery(query)`, tokenize `plain` for the scoring query, and when `opts.phraseFilter !== false` and phrases exist, drop scored rows whose `seq` lacks any phrase (a phrase is present when its tokens occur consecutively inside one sequence; a one-token phrase when the token occurs). Narrow candidates through `index.postings` before scanning sequences. Export `parseQuery`.

- [ ] **Step 4: Run** `node tests/research/test_core.js`. Expected: all tests pass, including the pre-existing ones unchanged.

- [ ] **Step 5: Commit** `git add tool/research/research_core.js tests/research/test_core.js && git commit -m "Researcher search: quoted phrases as a hard filter"` (with the trailer).

---

### Task 2: Adjacent-word boost

**Files:**
- Modify: `tool/research/research_core.js` (`search`)
- Test: `tests/research/test_core.js`

**Interfaces:**
- Consumes: `index.docs[i].seq`, `index.df`, `index.N` from Task 1 and the existing code; the idf formula `Math.log(1 + (N - n + 0.5) / (n + 0.5))` already in `search`.
- Produces: `search` honors `opts.phraseBoost` (number; default `PHRASE_BOOST = 0.5`; `0` disables; negative or non-finite values fall back to the default). Result shape unchanged. Query bigrams come from the tokens of `plain` in query order, before synonym expansion, distinct, at most 40.

- [ ] **Step 1: Write the failing tests** with this fixture (equal token multisets and lengths, so BM25 ties; `z2` has the adjacency but the later id):

```js
const brows = [
  { id: 'z1', title: 'perfusion lung ct', sum: '' },
  { id: 'z2', title: 'ct perfusion lung', sum: '' },
  { id: 'y1', title: 'grain subsidies', sum: '' },
  { id: 'y2', title: 'crop yields', sum: '' },
];
const bidx = RC.buildIndex(brows, []);
```

- `boost reorders adjacent first`: `search(bidx, 'ct perfusion')` ids start `['z2','z1']`; with `{ phraseBoost: 0 }` they start `['z1','z2']` (tie by id) and the two scores are equal.
- `boost size`: the score difference `z2 - z1` with the default equals `0.5 * Math.LN2` within `1e-9` (N is 4 and both words have df 2, so each idf is `ln 2`).
- `boost adds no rows`: id sets with and without the boost are identical on `pidx` for the query `ct perfusion stroke`.
- `boost bridges stop words`: index of `{ id: 'k1', title: 'ct perfusion', sum: '' }`, `{ id: 'k2', title: 'perfusion of the ct', sum: '' }` plus two unrelated filler rows. Both have the tokens `perfusion`, `ct` and the same length. Query `perfusion ct`: default order starts `['k2','k1']` (k2 has the bigram perfusion+ct once stop words go); with `{ phraseBoost: 0 }` it starts `['k1','k2']`.
- `boost is order-sensitive`: on `bidx`, query `perfusion ct` has no adjacent `perfusion ct` in `z1` (`perfusion lung ct`) or `z2` (`ct perfusion lung`), so their scores are equal and `z1` ranks first by id.
- `boost deterministic and bounded`: two runs of a 3,000-character query over a 1,225-row synthetic index return deep-equal results and finish under the same time bound as the existing `big query fast` test.
- `bad phraseBoost values`: `phraseBoost: -1`, `NaN` and `'x'` give the same ranking as the default.

- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL on the reordering and size assertions.

- [ ] **Step 3: Implement** the boost in `search`: after BM25 scoring, for each scored row count distinct query bigrams found consecutively in either sequence and add `phraseBoost * (idf1 + idf2) / 2` per bigram, where idf comes from `index.df` as in the existing term loop. Skip the step when the effective boost is 0 or the query has fewer than 2 tokens. Build a `Map` from bigram string to its boost weight once per query and scan each scored row's sequences once.

- [ ] **Step 4: Run** `node tests/research/test_core.js` and `node tests/research/run_testset.js`. Expected: unit tests all pass; the harness prints its summary without error (numbers are compared in Task 4).

- [ ] **Step 5: Commit** `git commit -m "Researcher search: adjacent-word boost"` with the trailer.

---

### Task 3: Tab text for phrases

**Files:**
- Modify: `tool/research/research_tab.js` (`run`, the input help text near `u.box`)
- Test: browser check (no automated UI test exists; `tests/research/ui_transparency_check.js` must still pass)

**Interfaces:**
- Consumes: `RC.parseQuery`, `RC.search(..., { phraseFilter })` from Task 1; the existing `render(msg)`, `updateMeta(tail)` and `el()` helpers.
- Produces: no new exports.

- [ ] **Step 1: Implement.** (a) Add one line to the search-box help text: put a phrase in double quotes to require it, for example `"CT perfusion"`. (b) In `run()`, when `RC.parseQuery(q).phrases.length` and the phrase-filtered `search` returns no live hits, call `RC.search(..., { phraseFilter: false })`; if that returns live hits, `render` a message naming the first phrase: no open opportunity contains the exact phrase “X”; remove the quotes to search the words separately. If it also returns none, keep the existing generic message. (c) When phrases are active and results show, add one meta line, `Exact phrase required: “X”, “Y”`, using the existing meta pattern. All text via `el(...)`/`textContent`.

- [ ] **Step 2: Verify in the built site.** Build with `sh app/build_pages.sh <scratch-dir>` and serve it locally. Check, desktop 1280 px and 375 px, light and dark:
  - `"ct perfusion"` shows the meta line and only rows containing the phrase; highlighting of matched words still works.
  - `"zzzz qqqq"` shows the exact-phrase message, not the generic one.
  - A 300-character paste containing `"gold standard"` shows no phrase line and results are unfiltered.
  - `""` alone shows the existing "Type or paste a few topic words" message.
  - Zero console errors; no sideways scroll.

- [ ] **Step 3: Run** `node tests/research/ui_transparency_check.js` and `node tests/research/test_core.js`. Expected: pass.

- [ ] **Step 4: Commit** `git commit -m "Researcher tab: phrase help text, active-phrase line, exact-phrase message"` with the trailer.

---

### Task 4: Harness flag, comparison run, docs

**Files:**
- Modify: `tests/research/run_testset.js`, `tests/research/test_core.js`, `docs/research_testset_results.md`, `README.md` (the "For researchers" paragraph on ranking), `AI_USAGE_LOG.md`

**Interfaces:**
- Consumes: `search(..., { phraseBoost })` from Task 2.
- Produces: `scoreTestset(rows, awards, groups, opts)` where `opts` (optional object, may be omitted) is spread into the `RC.search` options after `limit`; CLI flag `--phrase-boost=<number>`. The CSV is written only when no flag is given.

- [ ] **Step 1: Write the failing test** `scoreTestset passes search options`. Rows: Task 2's `z1` (`ic: 'AA'`) and `z2` (`ic: 'BB'`), plus the two filler rows (`ic: 'CC'`). One award with `abstract: 'ct perfusion'` and `ic: 'BB'`. Assert `ic_rank` is 1 by default and 2 with `scoreTestset(rows, awards, [], { phraseBoost: 0 })`. Also assert that omitting the fourth argument still works.

- [ ] **Step 2: Run** `node tests/research/test_core.js`. Expected: FAIL on the boost-sensitive rank.

- [ ] **Step 3: Implement** the `opts` pass-through and the `--phrase-boost=<n>` flag in `run_testset.js`. Keep the existing `--no-synonyms` flag working.

- [ ] **Step 4: Run the comparison** and record it. Run `node tests/research/run_testset.js --phrase-boost=0` (baseline), then the default (0.5), then `--phrase-boost=0.25` and `--phrase-boost=1` (sensitivity, reported only). Append a "Phrase boost run" section to `docs/research_testset_results.md`: date, awards run (say 10, or 20 only if the owner abstracts were added), pool size, a table of IC, mechanism and both-hits for each boost value, and the per-award change in `ic_rank` and `mech_rank` for 0 versus 0.5. State the ship rule's outcome in one sentence. If any hit count drops below baseline at 0.5, set `PHRASE_BOOST` to 0 in `research_core.js`, update the Task 2 default-size test to pass an explicit `phraseBoost: 0.5`, and say so.

- [ ] **Step 5: Docs.** In `README.md`, add one sentence to the researcher-tab ranking paragraph: words that appear next to each other rank higher, and a phrase in double quotes is required (quotes only count in a short search, not in a pasted abstract). Add an `AI_USAGE_LOG.md` row: tool, what for, and what a human checked.

- [ ] **Step 6: Run everything.** `node tests/research/test_core.js`, `node tests/research/run_testset.js`, `node tests/research/ui_transparency_check.js`. Expected: all pass. Then commit, push `researcher-phrases`, open a PR, wait for CI, merge, and confirm the live tab loads and `"ct perfusion"` filters (Task 3's checks on the deployed site).

---

## Self-review notes

- Spec coverage: quoted phrases as a filter (Task 1), adjacent boost (Task 2), user-visible behavior (Task 3), test-set evaluation (Task 4). The user asked for evaluation on the 20-award test set; only 10 awards exist and the harness cannot exercise quotes, both stated above.
- Names consistent across tasks: `parseQuery`, `phraseFilter`, `phraseBoost`, `PHRASE_BOOST`, `PHRASE_QUERY_MAX_CHARS`, `seq`.
- Task 2's stop-word bridge test is described by behavior; the implementer writes the exact fixture rows.

# Handoff: NC Grants Explorer, final state
Written Tuesday Sept 29, 2026, evening; last updated late Tuesday night. Due Wednesday Sept 30, 11:59 p.m.
Read time: about 7 minutes. Section 7 is for a coding agent; everyone else can stop at section 6.
For where every file lives, see `GUIDE.md`. For the team's reading packet, see `outs/todo/`.

---

## 1. The 30-second version

**The build is finished.** All three written deliverables exist and render. The tool, the
notebook and the top results list agree with each other, because they all run the same tier-rule file.

What is left:

- **Build the slides and record the 5-minute video.**
  - Paste `src/docs/presentation_brief.md` into Claude chat, with the images in `outs/figures/`.
  - The brief has the judging criteria, verified numbers, a 7-slide plan, a click-by-click demo
    script and the closing ask.
- **Commit and push the latest changes.**
  - The site, the partner correction and everything before them are already committed (`68ced3d`).
  - The "signature ink" redesign and the `outs/todo/` team folder are not yet committed.
- **Publish the website.**
  - It is built in `docs/`.
  - After pushing, turn on GitHub Pages: Settings → Pages → Deploy from a branch → `main` → `/docs`.
  - The site will be https://kapollol.github.io/SolveAThon_2026/.
  - The repo must be public on a free account.
- **Optional:** double-click `outs/grant-triage-tool.html` on another laptop to confirm it opens offline.

What we decided **not** to do, and say so openly in the notebook:

- **Tiers 1-3 were not hand spot-checked.** The team reviewed the research awards but ran out of time
  for the rest. The 60 blind hand labels are the evidence for those tiers.

---

## 2. Deliverables (competition items)

| Competition item | File | Notes |
|---|---|---|
| 1. Top results list with a one-line rationale | **`outs/top_results_with_rationale.xlsx`** (a tab per tier, impact breakdown, Grants.gov deadline and award, one-sentence rationale); machine-generated version `outs/top_results.xlsx` (and `.csv`); also notebook section 14 | 57 rows: DHHS 27 Tier 1, 24 Tier 2, 3 Tier 3; DMVA 3 Tier 3. The team's fill-in version is `outs/top_results_team.xlsx` (a tab per tier, the impact breakdown, Grants.gov deadlines and award ceilings, a blank rationale column). |
| 2. Notebook: notes, AI tools, key prompts, where the AI was wrong | `outs/solveathon_project.html` (source `src/solveathon_project.qmd`) | 19 sections, 30 figures plus a process diagram. Every dataset has at least one chart (inventory table in section 4); 19 tan takeaway notes explain the charts in plain language. Full prompt and schema, validation, limitations, AI disclosure. The tool is embedded. About 19 MB, opens offline. |
| 3. 5-minute video to leadership | slides not built yet | Slide brief: `src/docs/presentation_brief.md`; chart images: `outs/figures/` (11 PNGs) |
| Supporting: interactive tool | `outs/grant-triage-tool.html` | 3.4 MB, one file, offline. See "What the tool does now" below. |
| Supporting: website | `docs/` → https://kapollol.github.io/SolveAThon_2026/ | Landing page, tool, notebook, downloads. Built by `src/build_site.py`. |
| Supporting: project map | `GUIDE.md` | Where everything is, split into: what to submit, what to explain to the team, everything else |
| Supporting: team brief | `outs/team_brief_v2.docx` (source `src/docs/team_brief.md`) | Updated with final numbers and a new "How confident are we?" section |

### What the tool does now

- **Four piles** (Tiers 1-4), shown as big color-coded tiles, plus a line accounting for all 1,662 opportunities.
- **"Describe your situation" box.** It sets:
  - runway, match authority, staff and minimum award;
  - program priorities;
  - what matters most for the impact score, and the sort order.

  Each change shows as a chip you can undo.
- **Example buttons** under the box ("No match, half an FTE", "Big-picture planning", "Worth the
  effort"). Each applies a ready-made scenario in one click, starting from the opening scenario.
- **Presets** for whole personas: Mid-level writer, Deadline crunch, Division-backed, Planning ahead.
- **"Larger text" button** for projecting or screen sharing.
- **Detail panel for each opportunity:**
  - why this tier;
  - capability gaps;
  - impact breakdown;
  - key facts;
  - **"Who this reaches in NC"** (new): top counties, rural/suburban/urban split, counts by
    congressional district, and a "Show on the map" button;
  - quoted match evidence;
  - plan alignment.
- **Need map** with two layer groups: need by program area, and **where the people served live**
  (new). Overlays: counties, congressional districts (hover shows the district count), tracts, places.
- Reach vs intensity chart, a "How this works" tab, and CSV export.

---

## 3. Final numbers (use these, they match the notebook)

**The haystack**
- 1,662 opportunities in the file.
- 296 are open and state-eligible; 272 of those (92%) are NIH research.
- Only 6 posted, non-NIH opportunities are genuine DHHS candidates.

**Opening scenario for DHHS**
- 27 in Tier 1, 24 in Tier 2, 3 in Tier 3, and 366 in Tier 4 (partner-led research).
- 90 are "not this cycle", 5 are screened, and 1,147 are outside DHHS's scope.
- These counts changed on Sept 30, when awards and deadlines switched to what Grants.gov states
  (before: 23 / 23 / 3 / 365). See section 7.
- Total: 1,662. Every opportunity is accounted for.

**Data quality**
- The match percentage appears in only 6 rows, against 117 that require cost share.
- 355 "posted" opportunities had closed or been archived six weeks after the pull.

**AI vs. 60 blind hand labels**
| Label | Agreement |
|---|---|
| Match required | 93% |
| Capital project | 94% |
| Designation | 94% |
| DMVA alignment | 95% |
| Administrable by a state agency | 67% |
| DHHS alignment | 59% |
| Domain | 46% |

- Capabilities: 53% precision, 27% recall.
- Target population is not comparable, because the hand labels were free text.

**Where the AI was wrong** (these appear in the notebook and the brief):
- Prompt v2 was over-generous: wildfire and Sierra Leone programs were labeled DHHS-aligned.
- v3 over-corrected and rejected Title X.
- v3.1 got 13 of 14 dev cases right, and was then frozen.
- The model once wrote its own rule ("work happens outside the United States") into an evidence field.

**Who an opportunity reaches** (new, from ACS 2019-2023)
- Counties are grouped with the NC Rural Center density rule: 77 rural, 17 suburban / regional
  city, 6 urban.
- Example, veterans:
  - 618,846 in NC;
  - 39% live in rural counties;
  - the highest shares are in Currituck, Onslow, Hoke and Cumberland counties;
  - the most veterans are in districts 3 and 9.
- Districts are those drawn for the 118th Congress. NC redrew them for 2024.
- 170 of the 210 labeled opportunities are marked "all residents" or "system-level". The view is
  most informative for the other ~40.

**The research review**
- The team read 27 flagged research awards.
- They recommended a separate research tier for 23, marked 1 not relevant, and judged none to be DHHS-led.
- This became Tier 4.

---

## 4. Decisions made (all can be revisited)

| Decision | Choice | Where |
|---|---|---|
| Strategic plan | DHHS 2023-25 as provided by the competition (OSBM); DMVA 2025-29 | `data/manual/*_priorities.csv` |
| Domains | 8 (D01-D08); **no veterans domain** (d09 declined) | `00_config.R`, `src/docs/domain_taxonomy.md` |
| Prompt | Frozen at **v3.1** | `LLM_PROMPT_VERSION` in `00_config.R` |
| Hand labels | Left as the team wrote them, including 4 match slips | `data/manual/handlabels_60.csv` |
| Default match authority | "With approval" | `MATCH_AUTHORITY_DEFAULT` |
| Forecasts | Included in the opening scenario | `PRESETS` |
| Research awards | Tier 4 "partner-led", shown by default, can be hidden | tool toggle; `SHOW_SCREENED_DEFAULT` |
| Impact score | Five parts, user weights 0-3, "what matters most" selector; orders within a pile only | `IMPACT_WEIGHTS_DEFAULT` |
| Appropriation line | $1M, a labeled placeholder with no published NC rule | `APPROPRIATION_THRESHOLD_USD` |
| Spot-check | Tiers 1-3 not done; stated as a limitation | notebook section 15 |

---

## 5. What the team should do before submitting

1. **Build the slides and record the video** from `src/docs/presentation_brief.md`.
   - Rehearse the demo script twice.
   - Turn on "Larger text" before recording.
   - Take the fallback screenshot.
   - The strongest moments:
     - the NIH funnel;
     - "Deadline crunch" dropping Tier 1 to 1;
     - typing a scenario;
     - Title X's quoted match;
     - DMVA's Veterans Home grant in Tier 3;
     - the confidence chart;
     - the three decisions.
2. Open the notebook and the tool once each and skim them. Read the rationales in
   `outs/top_results_with_rationale.xlsx` and fix any you can't defend (in
   `data/manual/top_results_rationales.csv`, then re-run `src/R/07_top_results.R`).
3. Kent: commit and push the latest changes (see section 7 for a note on `.DS_Store` files).
4. Kent: rotate the Census API key when convenient. It was pasted in chat; it is not in any file
   except the gitignored `.Renviron`.

---

## 6. Five things every one of us must be able to explain

1. **Our user** is a mid-level grant writer inside DHHS who cannot commit match without a supervisor.
2. **Piles sorted by whose signature is needed**, plus Tier 4 for research a university would lead.
3. **The haystack:** of 296 open, state-eligible opportunities, 272 are NIH research. Only 6 posted
   non-NIH opportunities are DHHS business.
4. **Confidence:** the AI is strong on stated facts (match, construction, designation, 93-94%) and weaker
   on judgment (67% on "could a state lead it"). Every label is shown with its evidence, and the AI never
   assigns a tier.
5. **No single score** across piles: the impact score only orders within a pile.

---

## 7. For a coding agent picking this up

### Environment
- Project root: `/Users/kentalee/Documents/KALProjects/UNCProjects/SolveAThon_2026`.
- Software: R 4.5; Quarto 1.9.37; Ollama 0.34.4 with `qwen2.5:14b` and `nomic-embed-text`.
  Ollama is needed only to re-label.
- Every entry point calls `here::i_am(...)`, because `src/_quarto.yml` otherwise roots `here()` at `src/`.
- `00_config.R` forces a UTF-8 `LC_CTYPE`, because the text is hashed for the LLM cache. Do not remove it.
- The Census key lives only in the root `.Renviron`. Never write it into code or output.

### Rebuild (from `src/`, no key or model needed; everything is cached)
```bash
cd src
Rscript R/check_facts.R            # 24 of 24
Rscript R/05_export_tool_data.R    # data/processed/payload.json
Rscript tool/build_tool.R          # 32 tests (28 rule cases + ordering), then outs/grant-triage-tool.html
Rscript R/07_top_results.R         # outs/top_results.csv/.xlsx
quarto render solveathon_project.qmd
python3 export_slide_figures.py    # outs/figures/*.png for the slides (matched by chart title)
python3 build_site.py              # docs/ website for GitHub Pages (checks nothing contains the Census key)
```

A clean-copy rebuild was verified:
- 24/24 facts pass;
- all 32 tests pass;
- all 1,662 opportunities are placed;
- the payload is byte-identical apart from its timestamp.

### Invariants
- **Tier rules exist only in `src/tool/tiering.js`.** R runs the same file through V8
  (`run_tiering_js`, `run_tiering_piles_js(payload, settings)`).
- The `payload.json` schema `1.0.0` must equal `Tiering.SCHEMA`.
- Payload format:
  - dates are integer days since the epoch;
  - lists are wrapped in `I(as.character(...))`;
  - it is written with `digits = NA`.
- LLM cache key = sha256(model + digest + prompt version + prompt + schema). Changing the prompt re-labels
  all 210 opportunities.
- `06_spotcheck_sheet.R` never overwrites a template that already holds verdicts.
- The team's research-review verdicts are in `data/manual/spotcheck_template.csv` and `spotcheck.csv`.

### Added in the last session (all rebuilt and verified)
- **Tool redesign** (`src/tool/styles.css`, "Visual refresh" block at the end):
  - summary tiles (built in `renderPiles` in `ui.js`);
  - example scenario buttons (reset to the opening state first);
  - a "Larger text" presentation mode (`html.present { zoom }`);
  - tinted pile headers, cards and impact bars;
  - checked in light mode, dark mode and at 375px width.
- **Scenario parser** (`parseScenario` in `ui.js`) also sets:
  - minimum award (`AWARD_RE`);
  - impact weights (`IMPACT_WORDS`);
  - sort order.
- **Who this reaches.**
  - Data side (`05_export_tool_data.R`): `add_population_geography()` adds `county` (and, for ACS
    populations, `district`) counts to each population; `community_context()` adds county
    population, rurality, district names and caveats as `payload$community`.
  - New cache: `data/cache/api/acs_2023_nc_congressional_district.rds`.
  - Tool side (`ui.js`): `whereTheyLive()`, `reachSection()`, `drawPopulationMap()`.
  - Checks: county counts sum exactly to the state totals, and district hover counts match the ACS.
- **Notebook** (29 charts):
  - §14 describes using the tool and the community view;
  - two new charts (rural/suburban/urban share by population; populations by district);
  - §4 sources and "where charted" tables list the district data and TIGER land area;
  - §3 steps table and §16 limitations updated.
- **Grants.gov awards and deadlines (Sept 30).** `src/R/01c_grantsgov_awards.R` reads the full Grants.gov
  record for all 872 state-eligible opportunities.
  - **Award:** now the award ceiling Grants.gov states (351 of 872 state one). Where it states none,
    the award is total funding ÷ expected awards (Grants.gov's figures, else the export's), marked
    "est." in the tool and named in an "Award source" column in the team sheet. That estimate was more
    than 2x off the real ceiling for 35% of opportunities that have both, which is why a stated
    ceiling always wins. Among the 57 top results, 4 still have no award figure: two DMVA GPD
    forecasts, an FDA forecast and a FEMA grant, none with total funding or an award count to divide.
    3 have no people count (people with a substance use disorder, which has no NC count), so help per
    person is blank for 7. A ceiling
    under $1,000 is treated as a placeholder, which affected one forecast.
  - **Deadline:** now Grants.gov's current application deadline (its estimate, for forecasts).
  - **Effect on the opening scenario:** it went from 23 / 23 / 3 / 365 to 27 / 24 / 3 / 366.
  - **The three decisions were updated:**
    - viral hepatitis is now Tier 1's top result: a forecast due Feb 16, 2027, about $7.5M per award (estimated);
    - the Preschool Development Grant is up to $15M, due Nov 20;
    - 17 of 24 Tier 2 items wait on a partner.
  - The verified-facts check still uses the export's own dates (`export_close_day` in the payload),
    so 296 / 272 still reproduces.
- **Filled-in spreadsheet** `outs/top_results_with_rationale.xlsx` (the list to submit): the same layout as the team sheet, with one sentence per opportunity (why it ranks where it does, plus what the grant funds, taken from its Grants.gov description). Source: `data/manual/top_results_rationales.csv`; the build stops if any row lacks a sentence. Kent asked that the AI disclosure not list these.
- **Team spreadsheet** `outs/top_results_team.xlsx`, written by `write_team_sheet()` in `07_top_results.R`:
  - a "How to fill this in" tab and one tab per tier;
  - the impact score and its five parts (0-100);
  - opportunity number and ID;
  - the Grants.gov deadline (as a real date), award ceiling and floor;
  - a blank yellow rationale column, and the link;
  - no rules column.
- **Notebook:**
  - §9 was rewritten around the Grants.gov figures (ceiling vs old estimate, ceiling distribution,
    deadline comparison);
  - new "impact score, part by part" chart and table in §11;
  - renamed **NC Grants Explorer**, with the team as authors.
- **Rename** to NC Grants Explorer throughout (the tool, site, notebook and docs). File names such as
  `grant-triage-tool.html` are unchanged, so links keep working.
- **Website** (`docs/`, built by `src/build_site.py` from `src/site/index.html`).
  - The landing page follows Understand → Solve → Evaluate → Mobilize, using real data only.
  - **Correction made while building it:** decision 3 no longer says a pre-approved match budget
    moves many Tier 2 items to Tier 1. We checked, and full match authority moves only 1 (27/24 →
    28/23 with current data).
  - 17 of 24 Tier 2 items wait on a partner, so decision 3 is now "line up standing partners for
    research evaluation (9) and workforce training (6)". Fixed in the site, the slide brief, the
    notebook §17 and the team brief.
- **"Signature ink" redesign** (applied from `less-ai-redesign.patch`, Sept 30).
  - Landing page: a manila routing-slip hero that adds up to all 1,662, plus funnel bars drawn to scale.
  - Tool styles: Libre Franklin, flat panels.
  - **New tier colors everywhere:** ink blue `#23408E`, ochre `#B7791F`, brick `#A63D2F`, gray `#6E7479`.
  - Carried through to:
    - the notebook (`pal` in the setup chunk, CSS tokens, all hardcoded chart colors, flat KPI tiles, manila takeaway boxes, Libre Franklin via `include-in-header`);
    - the tool's font link (`src/tool/index.html`; offline it falls back to Franklin Gothic or Helvetica);
    - the slide images;
    - the slide brief's design section.
  - Palette check: it passes the colorblind and normal-vision separation checks. It is flagged
    only for the deliberately dark navy and the neutral gray, and every tier also has a shape and
    a text label.
- **Interactive charts.** A `knit_print.ggplot` method in the notebook's setup chunk shows every
  ggplot as a plotly chart (hover text from each chart's `text` aesthetic, zoom, PNG download), with
  the title and subtitle above as HTML. It also saves a static PNG of every chart to
  `outs/figures/chunks/<chunk label>.png`. Chunks marked `static: true` (the two small-multiple map
  grids) show that PNG instead. `src/export_slide_figures.py` now copies slide images from
  `outs/figures/chunks/`, and adds `12_impact_score_breakdown.png`.
- **Slide brief** `src/docs/presentation_brief.md`.
- **Figure export** `src/export_slide_figures.py`. `outs/figures/` is now tracked in git.
- `GUIDE.md` at the root.

### Not done / optional
- **Git note.** `.DS_Store` files were committed in `833f08a` even though `.gitignore` lists them.
  To stop tracking them: `git rm --cached .DS_Store data/.DS_Store src/.DS_Store`.
- District counts use the 118th Congress districts. Current (2024) districts would need ACS 2024
  1-year data by district plus the 2024 boundary file.
- The video script (only when Kent asks).
- Commit and push (only on Kent's explicit go; see `.gitignore` for which `outs/` files are tracked).
- The notebook is about 19 MB because of embedded figures (dpi already lowered to 120 in the setup chunk).
- The tool now shows **who an opportunity reaches**. The detail panel has a "Who this reaches in NC" section: top counties by count and by share, a rural/suburban/urban split (NC Rural Center density rule), and counts by congressional district from ACS 2019-2023 by district (118th Congress, cached as `data/cache/api/acs_2023_nc_congressional_district.rds`). The map has a matching "Where the people served live" layer. Code: `add_population_geography()` and `community_context()` in `05_export_tool_data.R`; `whereTheyLive()`, `reachSection()` and `drawPopulationMap()` in `ui.js`. Limitation: 170 of 210 labeled opportunities serve all residents or are system-level, so the view is most useful for about 40.
- The scenario box (`parseScenario` in `src/tool/ui.js`) now also sets the minimum award ("at least $500k", "awards over 1 million") and the impact weights and sort order ("reach the most people", "help per person", "biggest grants", "closing soon"). Each match shows as an undoable chip.
- Orphans that are harmless to leave:
  - legacy `src/diagnostic.qmd`, `src/extra.Rmd` and `src/solveathon_project.Rmd`;
  - old files in `data/processed/`;
  - unused cache files from before the UTF-8 fix.
- Ask Kent before cutting anything. Section 13 questions (capability levels, domains, hand-label
  correctness, how real agencies are characterized) are his to decide.

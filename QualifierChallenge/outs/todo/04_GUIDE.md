# Project Guide: Where Everything Is and What It Is

NC Grants Explorer · Solve-A-Thon 2026 · Team: Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt · due Wednesday Sept 30, 11:59 p.m.

This guide has three parts:
1. **What to submit.** The files the competition asks for.
2. **What to explain to the team.** The files and ideas every teammate should know before the video and the questions.
3. **Everything else.** Code, data, caches, and leftovers.

All paths are relative to the project folder, `SolveAThon_2026/`.

---

## Part 1. What to submit

The competition asks for three things. Two are ready. The video still has to be recorded.

| # | The competition asks for | Our file | Status |
|---|---|---|---|
| 1 | A top results list with a one-line rationale per opportunity, tied to the match criteria | `outs/top_results_with_rationale.xlsx` (a tab per tier; the machine-generated version is `outs/top_results.xlsx`) | Ready |
| 2 | The work as a notebook, with notes, the AI tools used, the key prompts, and at least one place the AI was wrong and how it was caught | `outs/solveathon_project.html` | Ready |
| 3 | A 5-minute recorded presentation to leadership | not made yet | **To do** |

**Website (GitHub Pages):** https://kapollol.github.io/SolveAThon_2026/
It is built into `docs/` by `src/build_site.py`:
- `index.html`: a one-page story that follows the competition's loop (Understand → Solve → Evaluate → Mobilize). It covers the user and their five criteria, the four piles, a real sample of top results, how sure to be, what the AI got wrong, and three decisions for leadership;
- `tool.html`;
- `notebook.html`;
- `downloads/`: the top results.

To publish or update it, see Part 3, "Publishing the website".

**Include with the submission:**

| File | Why |
|---|---|
| `outs/grant-triage-tool.html` | The interactive tool. It is also embedded in the notebook, but the standalone file is the easiest way for a judge to try it. Double-click to open. It works offline. |

**What the tool does:**
- **Four piles** shown as color-coded tiles, plus a line that accounts for all 1,662 opportunities.
- **"Describe your situation" box.** It sets:
  - runway, match authority and staff;
  - minimum award;
  - program priorities;
  - what matters most for impact.

  Each change is an undoable chip.
- **Example buttons** and **presets** apply ready-made scenarios in one click.
- **"Larger text"** enlarges everything for a projector.
- **Clicking any opportunity** shows:
  - why it is in its tier;
  - capability gaps;
  - the impact breakdown;
  - quoted match evidence;
  - plan alignment;
  - **"Who this reaches in NC"**: the counties where its population lives, the rural/suburban/urban
    split, counts by congressional district, and a button to draw it on the map.
- **Need map:** need by program area, or where a population lives. Overlays: counties,
  congressional districts, tracts or towns.
- **Reach vs intensity** chart, a **How this works** tab, and **CSV export**.

### 1. Top results list: `outs/top_results.xlsx`

**What it has:** 57 rows.
- DHHS: 27 in Tier 1, 24 in Tier 2, 3 in Tier 3.
- DMVA: 3 in Tier 3.

**Filled-in version:** `outs/top_results_with_rationale.xlsx` (copied to `outs/todo/09_top_results_with_rationale.xlsx`) has the same layout, with a one-sentence rationale per opportunity: why it ranks where it does, and what the grant funds, taken from its Grants.gov description. **This is the list to submit.** The sentences live in `data/manual/top_results_rationales.csv` and the EXPLANATION tab in `data/manual/top_results_explanation.txt`; edit them there and re-run `07_top_results.R`.

**Team fill-in version:** `outs/top_results_team.xlsx` (copied to `outs/todo/08_top_results_to_fill_in.xlsx`). It has a tab per tier, the impact score and its five parts, the Grants.gov deadline and award ceiling, and an empty rationale column for the team to write.

**Each row shows:**
- tier and rank within the tier;
- impact score;
- title, issuing agency, status, deadline and estimated award;
- a link to the opportunity;
- a **one-line rationale** that walks the five criteria in order: can we apply, do we have the capabilities, is there runway, what is the award, is the match survivable.

**What scenario it uses:** the tool's opening scenario. That is a mid-level writer with about one month of runway who needs a supervisor's approval for match, with one staff FTE and forecasts included.

**Where else it appears:** notebook section 14, "Top results".

### 2. Notebook: `outs/solveathon_project.html`

One file of about 19 MB. Double-click to open; it works offline. It has 19 sections, 30 charts (28 interactive: hover for the numbers, drag to zoom, save as PNG; the two small-multiple map grids are images) and a process diagram, and the interactive tool is embedded in section 14.

**Where each competition requirement is:**

| Requirement | Section |
|---|---|
| Notes and process | §3 "How we built this": diagram, plus a table of each step and what changed because of it |
| AI tools used | §18 AI usage disclosure (Claude Code for building; the local model `qwen2.5:14b` for labeling) |
| Key prompts | §12 prints the full labeling prompt and output schema, generated from the code that sent them |
| Where the AI was wrong and how we caught it | §12 (prompt v2 too generous, v3 over-corrected on Title X, the confusion tables, real disagreement examples) and §16 (it invented a rule in an evidence field) |
| Data sources and dictionary | §4 (includes a table of which chart shows which dataset) |
| Evaluation and limitations | §15 and §16 |

**Source file:** `src/solveathon_project.qmd`. To rebuild, run `cd src && quarto render solveathon_project.qmd`.

### 3. Video (to do)

- **Slide brief:** `src/docs/presentation_brief.md`. Paste it into Claude chat and attach the 11
  images in `outs/figures/`; Claude will build the deck. The brief includes:
  - the five judging criteria;
  - verified numbers;
  - a 7-slide plan with timings;
  - a click-by-click demo script with the counts you will see;
  - three decisions for leadership;
  - likely questions.
- **Before recording:**
  - open the tool full screen and click "Larger text";
  - rehearse the demo twice ("Reset everything" is in the Assumptions panel).
- The team brief's section 8 has an older outline. The slide brief replaces it.

---

## Part 2. What to explain to the team

**Team reading packet: `outs/todo/`.** Start with `00_START_HERE.md`. It has the deadline
checklist, the reading order, the ten things everyone must be able to explain, and the rubric
mapping. The folder holds copies of:
- the team brief;
- the slide brief;
- the handoff and this guide;
- the AI disclosure;
- the tool;
- the top results;
- the slide charts.

Refresh the copies with `python3 src/build_todo.py`. The start page's source is `src/todo/00_START_HERE.md`.

### Files the team should read

| File | What it is | Who needs it |
|---|---|---|
| `outs/team_brief_v2.docx` (source `src/docs/team_brief.md`) | Plain-language summary of the whole project: the user, the piles, the findings, how confident we are, the video outline, key terms. **Section 7 lists five things everyone must be able to explain.** Section 12 covers confidence. | Everyone, before the video |
| `handoff.md` | Current status, final numbers, decisions made, what is left. The last section is for a coding agent. | Anyone picking up work |
| `outs/grant-triage-tool.html` | The tool itself. Everyone should try it once: type a scenario, open a card, change a setting. | Everyone |

### The ideas everyone must be able to explain

1. **Our user.** A mid-level grant writer inside NC DHHS who cannot commit matching funds without a supervisor. Not leadership; leadership is the video's audience.
2. **Piles sorted by whose signature is needed:**
   - **Tier 1:** the writer can act alone.
   - **Tier 2:** needs a supervisor or division (match approval, a partner, more staff).
   - **Tier 3:** needs the secretary or legislature (appropriation, construction, formal designation).
   - **Tier 4:** research a university would lead, with the agency as partner.
3. **The haystack.** Of 296 open, state-eligible opportunities, 272 (92%) are NIH research. Only 6 posted, non-NIH opportunities are genuine DHHS candidates. Most real options are *forecasts*.
4. **Impact ranking orders within a pile, never across piles.** The writer chooses what matters most:
   - plan fit;
   - people reached;
   - help per person;
   - award size;
   - their program priorities.

   A big grant you can't staff should not outrank a small one you can run tomorrow.
5. **How confident we are.** Against 60 blind hand labels, the AI is reliable on stated facts:
   - match 93%;
   - construction 94%;
   - designation 94%.

   It is weaker on judgment calls:
   - "could a state agency lead it" 67%;
   - DHHS plan fit 59%.

   The AI never assigns a tier; written rules do, and every card shows the evidence.
6. **Where the AI was wrong, and how we caught it:**
   - The first prompt called wildfire and Sierra Leone programs "aligned with DHHS." We caught this by reviewing its labels by hand.
   - The stricter version rejected Title X. We caught this with known test cases.
   - Once, it wrote its own rule into a field meant for a direct quote. We caught this because the tool shows every quote.
7. **What the AI found that the data missed:**
   - Title X is marked "no cost sharing" in the file, but its announcement requires outside funding.
   - The Veterans Home construction grant's 35% match rate is not in the file.
8. **The known limitation.** Match percentages are almost never in structured data: 6 of 1,662 rows. **Tiers 1–3 were not hand spot-checked**, and we say so openly.
9. **Who an opportunity reaches.** The tool shows where the people an opportunity serves live:
   - by county;
   - rural, suburban or urban;
   - by congressional district.

   This is where people live, not where the money goes. It is most informative for opportunities
   labeled with a specific group, such as children or veterans.
10. **DMVA as the contrast.** DMVA's best match, the State Veterans Home Construction Grant, lands in Tier 3. The agency's best opportunity is the one it cannot act on alone.

### Team-made files (their work, cited in the notebook)

| File | What it is |
|---|---|
| `data/manual/handlabels_60.csv` | The team's 60 blind hand labels, the answer key for measuring the AI. Left exactly as written, including 4 match slips. |
| `data/manual/spotcheck.csv` and `data/manual/spotcheck_template.csv` | The team's review of 27 research awards flagged "check this". This review is why Tier 4 exists. |
| `data/manual/data_dictionary.csv` | The team's written data dictionary. It is shown in notebook §4. |
| `src/docs/handlabel_instructions.md` | The instructions the team followed for hand labeling |

### Decisions the team should know (all can be revisited)

| Decision | Choice |
|---|---|
| Strategic plans | DHHS 2023–25 and DMVA 2025–29, the versions on the OSBM site the competition provides |
| Program domains | 8, with no separate veterans domain |
| Default match setting | "With approval" |
| Forecasts | Included by default |
| Research awards | Tier 4, shown by default, can be hidden |
| Prompt | Frozen at v3.1 |
| Appropriation line | $1M, a labeled assumption with no published NC rule behind it |

---

## Part 3. Everything else

### Top-level files

| File | What it is |
|---|---|
| `README.md` | Short overview: how to open the deliverables and how to rebuild |
| `GUIDE.md` | This file |
| `handoff.md` | Status and next steps (see Part 2) |
| `.gitignore` | Keeps large data, caches and private files out of git. Only the submission files in `outs/` are tracked. |
| `.Renviron` | **Private.** Holds the Census API key. It is gitignored and must never be shared. Rotate the key when convenient; it was pasted into chat once. |
| `SolveAThon_2026.Rproj` | RStudio project file |
| `.RData`, `.Rhistory`, `.Rproj.user/` | RStudio session leftovers; not used |

### Code: `src/`

**Pipeline scripts (`src/R/`)** run in this order:

| File | What it does |
|---|---|
| `00_config.R` | **Every setting and threshold** is in one place. The top block is the one you are most likely to change: appropriation line, staff per application, alignment cutoffs. It also holds defaults, presets, domains, populations and capabilities. |
| `01_load_clean.R` | Reads the Grants.gov export and cleans it: dates, eligibility, NIH flag, implied award, match text |
| `check_facts.R` | Recomputes the 24 verified facts. Must print "24 of 24". |
| `01c_grantsgov_awards.R` | Reads every state-eligible opportunity's full Grants.gov record and keeps the stated award ceiling and floor, total funding, expected awards and the current deadline (`data/processed/grantsgov_awards.rds`). The tool uses the stated ceiling; where there is none, it estimates total ÷ expected awards and marks it "est.". |
| `01a_grantsgov_enrich.R` | Checks each opportunity's current status on Grants.gov and downloads full announcements for 278 candidates (116 had one) |
| `01b_alignment.R` | Text-similarity scores against each strategic plan. Also checks every plan row against its PDF page. |
| `02_capabilities.R` | Requirement profiles, the agency capability profiles, and the bridge that runs the tier rules from R |
| `03_llm_label.R` | The local AI labeler: prompt, schema and cache. Labels 210 candidates. |
| `03b_handlabel_sheet.R` | Made the 60-row hand-label sheet. Already done; do not re-run. |
| `04_validate.R` | Compares AI labels with the hand labels |
| `05_export_tool_data.R` | Builds `data/processed/payload.json`, all the data the tool needs, including the county need layers |
| `06_spotcheck_sheet.R` | Makes the spot-check sheet (`outs/spotcheck_for_team.xlsx`). It never overwrites a filled-in sheet. |
| `07_top_results.R` | Makes the top results list (`outs/top_results.csv`/`.xlsx`) and the team's fill-in version (`outs/top_results_team.xlsx`: a tab per tier, the impact score and its five parts, the Grants.gov deadline and award ceiling, and an empty rationale column) |

`05_export_tool_data.R` also adds the county and congressional-district counts behind "Who this
reaches" (`add_population_geography()`, `community_context()`).

**`src/export_slide_figures.py`** saves the 11 slide charts from the rendered notebook to
`outs/figures/`.

**The tool (`src/tool/`):**

| File | What it is |
|---|---|
| `tiering.js` | **The tier rules, the only copy.** The tool, the notebook and the top results list all run this file. |
| `ui.js` | Everything on screen: controls, scenario box, cards, "Who this reaches" section, map (need and population layers), charts, export |
| `index.html`, `styles.css` | The tool's page layout and styling |
| `tiering_cases.json` | Test cases for the rules |
| `build_tool.R` | Runs 32 tests, then assembles everything into `outs/grant-triage-tool.html`. It refuses to build if a test fails. |

**Documents (`src/docs/`):**

| File | What it is |
|---|---|
| `team_brief.md` | Source of the team brief |
| `ai_usage.md` | Source of the AI disclosure (notebook §18) |
| `presentation_brief.md` | Brief to paste into Claude chat to build the 5-minute slide deck |
| `domain_taxonomy.md` | Definitions of the 8 program domains |
| `handlabel_instructions.md` | Hand-labeling instructions |

**Other files in `src/`:**
- `_quarto.yml`: render settings. Output goes to `outs/`.
- `solveathon_project.qmd`: the notebook source.
- Legacy files, not rendered and safe to ignore:
  - `legacy_solveathon_project.qmd`
  - `solveathon_project.Rmd`
  - `diagnostic.qmd`
  - `extra.Rmd`

### Data: `data/`

**`data/raw/`: original inputs, never modified**

| Path | What it is |
|---|---|
| `grants/grants-search-202608182008.csv` | **The competition's Grants.gov export**: 1,662 opportunities, 40 columns, pulled Aug 18, 2026 |
| `grants/nofo/` | Downloaded full announcements (about 116 MB, gitignored). Their text is saved in `data/processed/grantsgov_enrichment.rds`. |
| `strategic_plans/NCDHHS 2023-25 Strategic Plan.pdf` | DHHS plan we use (the competition's version) |
| `strategic_plans/NCDMVA_StratPlan25-29_2025.09.03.pdf` | DMVA plan we use |
| `strategic_plans/DHHS_StrategicPlan_2024-2026_Final.pdf` | Newer DHHS plan. **Not used**; noted as a limitation. |
| `Underlying Cause of Death, 1999-2020.tsv` | CDC WONDER all-cause deaths by county. **Not used**: it counts all causes, not overdoses. We used NCHS model-based overdose rates instead. |
| `acs/`, `boundaries/`, `cdc_places/`, `cdc_wonder/`, `fema/`, `hrsa/`, `samhsa/`, `usaspending/` | Empty folders. Those sources were pulled from their APIs and saved in `data/cache/api/`. |

**`data/manual/`: hand-built tables**

| File | What it is |
|---|---|
| `dhhs_priorities.csv` | DHHS 2023–25 plan as a table: 106 rows, with page numbers. The `alignable` column marks program rows (79) versus internal operations (27). |
| `dmva_priorities.csv` | DMVA plan as a table: 37 rows (24 program, 13 internal) |
| `dhhs_priorities_2024-26_unused.csv` | Table from the newer DHHS plan. Kept to show the plan is swappable; not used. |
| `agency_capabilities.csv` | The capability profiles: 14 capabilities × 2 agencies, each with a control level, a source link and what resolving a gap takes |
| `prompt_dev_cases.csv` | 16 known cases used to test prompt versions |
| `handlabels_60.csv`, `handlabels_60_template.csv` | Team hand labels, and the blank template |
| `spotcheck.csv`, `spotcheck_template.csv` | Team research review, and the sheet |
| `data_dictionary.csv` | Team data dictionary |

**`data/processed/`: pipeline outputs**

| File | What it is |
|---|---|
| `payload.json` | **All data the tool uses.** It is embedded into the tool HTML. |
| `llm_labels.rds` | The AI's labels for 210 candidates (prompt v3.1) |
| `llm_labels_v2_partial.rds` | Earlier prompt v2 labels, kept for the before/after comparison |
| `validation.rds` | AI vs. hand-label results |
| `grantsgov_enrichment.rds` | Current status, plus full-announcement text |
| `alignment.rds` | Text-similarity scores |
| `capabilities_phase1.rds` | Rule-based requirement profiles |
| `prompt_v3_test_log.txt` | Log of the prompt tests |
| `grants_domains.parquet`, `grants_rule_review_sample.csv`, `legacy_domain_validation_metrics.csv` | Leftovers from the original plan; nothing reads them |

**`data/cache/`: saved responses, so nothing is re-downloaded or re-asked**

| Path | What it is |
|---|---|
| `api/acs_2023_nc_congressional_district.rds` | ACS 2019-2023 counts by congressional district (118th Congress) for "Who this reaches" |
| `api/` | ACS (Census), CDC PLACES, HRSA shortage areas, OpenFEMA, NCHS overdose, county boundaries, and Grants.gov responses, each with an access date. The `usa_*.rds` files are USAspending pulls for a "with more time" idea and are not used. |
| `llm/label/`, `llm/embed/` | Every AI response and embedding, keyed by a hash of the model, prompt version and exact prompt. This is why the notebook renders without running the model. |
| `boundaries/` | Map boundaries: counties, congressional districts, tracts, places |

### Generated outputs: `outs/`

| File | What it is | In git? |
|---|---|---|
| `solveathon_project.html` | Notebook | Yes |
| `grant-triage-tool.html` | Tool | Yes |
| `top_results.xlsx`, `top_results.csv` | Top results list | Yes |
| `team_brief_v2.docx` | Team brief | Yes |
| `spotcheck_for_team.xlsx` | Spot-check sheet with instructions and dropdowns | No |
| `tables/verified_facts_check.csv` | The 24 facts check | No |
| `tables/validation_summary.csv`, `tables/validation_by_class.csv` | AI accuracy tables | No |
| `figures/` | Eleven chart images exported from the notebook for the slides by `src/export_slide_figures.py` (see `src/docs/presentation_brief.md`) | Yes |

### Publishing the website (GitHub Pages)

| Path | What it is |
|---|---|
| `src/site/index.html` | Landing-page template ("signature ink" style: Libre Franklin font, ink-blue accent, a manila "routing slip" hero showing how many opportunities each signer gets). The numbers, the sample of top results and the veterans figures are filled in from `payload.json` and `top_results.csv` at build time. |
| `src/build_site.py` | Copies the tool, notebook and top results into `docs/`, fills in the landing page, labels table cells so rows stack on phones, and adds `.nojekyll`. It refuses to publish if any file contains the Census key. |
| `docs/` | The built website. **Do not edit it by hand**; rebuild it. |

**First time only:**
1. Commit and push `docs/` to `main`.
2. On GitHub, open the repository's **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**, branch **main**, folder **/docs**, and Save.
4. After a minute or two the site is live at https://kapollol.github.io/SolveAThon_2026/.

GitHub Pages on a free account needs the repository to be **public**. Publishing makes the notebook
public, including the hand-label examples and team notes it quotes.

**After any change:** rebuild (below), commit, and push. Pages updates itself.

### How to rebuild everything

No Census key or AI model is needed; everything comes from the caches.

```bash
cd src
Rscript R/check_facts.R
Rscript R/05_export_tool_data.R
Rscript tool/build_tool.R
Rscript R/07_top_results.R
quarto render solveathon_project.qmd
python3 export_slide_figures.py
python3 build_site.py
```

Only re-labeling needs the local model (Ollama with `qwen2.5:14b` and `nomic-embed-text`). Only a fresh Census pull needs the key in `.Renviron`.

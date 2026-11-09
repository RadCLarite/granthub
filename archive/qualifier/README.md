# NC Grants Explorer

Solve-A-Thon 2026 · NC's Hidden Treasure

**Team:** Kent Lee, Everett Foo, Marco Gullotto, Matthew Martin and Noah Goldblatt.

A tool for a grant writer inside a North Carolina state agency. It sorts federal funding
opportunities into three piles by **whose signature is needed**: the writer's, a supervisor's, or
the secretary's or legislature's, plus a fourth pile for research awards a university would lead.
Every opportunity shows the rule that put it there; within a pile, the writer ranks by an impact
score whose weights they set. All 1,662 opportunities in the file are accounted for on screen.

**Website:** https://kapollol.github.io/SolveAThon_2026/ (GitHub Pages, served from `docs/`). It has a landing page, the interactive tool
(`tool.html`), the notebook (`notebook.html`) and the top-results downloads.

## Open the deliverables

| What | Where | How |
|---|---|---|
| Interactive tool | `outs/grant-triage-tool.html` | Double-click. One file, works offline, no server. |
| Analytical notebook | `outs/solveathon_project.html` | Double-click. The tool is embedded in section 14. |
| Top results list | `outs/top_results_with_rationale.xlsx` (also notebook section 14) | A tab per tier: every Tier 1-3 opportunity with its impact breakdown, Grants.gov deadline and award, and a one-sentence rationale. `outs/top_results_team.xlsx` is the same with the rationale left blank. |
| Team brief | `outs/team_brief_v2.docx` | Plain-language summary for the team. |
| Hand labels and spot-check sheets | `data/manual/handlabels_60.csv`, `outs/spotcheck_for_team.xlsx` | Instructions in `src/docs/handlabel_instructions.md` |

## Layout

Everything lives under three folders:

- `src/` is everything a person wrote: the notebook (`solveathon_project.qmd`), the R pipeline
  (`src/R/`), the tool's source (`src/tool/`), and documentation (`src/docs/`, including the
  AI-usage disclosure).
- `data/` holds inputs and caches: `raw/` (never modified), `manual/` (hand-authored tables:
  strategic plans, capability profiles, data dictionary, hand labels), `cache/` (every API and
  model response, so nothing is re-downloaded or re-queried), and `processed/` (pipeline outputs,
  including `payload.json`, the tool's data).
- `outs/` holds generated files only and can be deleted and rebuilt.

## Rebuild from scratch

No Census key and no local model are needed; everything comes from the committed caches.

```bash
cd src
Rscript R/check_facts.R            # the 24 verified facts; must print "24 of 24 rows pass"
Rscript R/01c_grantsgov_awards.R     # Grants.gov award ceilings and deadlines (cached)
Rscript R/05_export_tool_data.R    # data/processed/payload.json
Rscript tool/build_tool.R          # outs/grant-triage-tool.html (runs 32 tests first)
Rscript R/07_top_results.R         # outs/top_results.csv and .xlsx
quarto render solveathon_project.qmd   # outs/solveathon_project.html
python3 export_slide_figures.py        # outs/figures/ (slide charts)
python3 build_site.py                  # docs/ (the GitHub Pages website)
```

Requires R 4.5 with the packages loaded in `src/R/*.R` (including `V8`, `sf`, `tidycensus`,
`pdftools`, `openxlsx`) and Quarto 1.9.

To **re-run** the steps that call outside services: `src/R/01a_grantsgov_enrich.R` (Grants.gov,
no key), `src/R/03_llm_label.R` (needs [Ollama](https://ollama.com) with `qwen2.5:14b` and
`nomic-embed-text`), and the ACS pull (needs `CENSUS_API_KEY` in a root `.Renviron`). All three
reuse their caches and only call out for items not already cached.

## Where things are decided

- Every threshold and default: `src/R/00_config.R` (user-tunable values at the top).
- The tier rules: `src/tool/tiering.js`, the only copy. R runs the same file through V8.
- Strategic plans used: DHHS 2023-2025 and DMVA 2025-2029, the versions on the OSBM site the
  competition provides.

See `GUIDE.md` for where everything is and what it is, and `handoff.md` for the current status and open items.

# Repository map

Written when the repository was reorganized into a clean top-level layout (2026-11-08). The reorganization was done in three steps (code and data, qualifier inputs, archive), each checked before merging.

| Path | What it is |
|---|---|
| `README.md`, `LICENSE`, `NOTICE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` | Public front matter. Apache-2.0. |
| `CLAUDE.md` | Short instructions for AI coding sessions: commands and constraints. |
| `AI_USAGE_LOG.md` | Record of AI use in building the project. `docs/improvement-log.md` records changes made with AI help. |
| `.here`, `granthub.Rproj` | Root markers so `here::here()` resolves to the repository root. |
| `api_keys.env.example`, `.Renviron.example` | Templates for local keys. Real key files are git-ignored. |
| `R/` | The numbered R pipeline (`00_config.R` holds every threshold and path), helpers, backtests, `check_facts.R`, `ocr_vision.swift`. |
| `tool/` | The static web page `matchmaker.html` (published as `/matchmaker/`), plus `ranker.js`, `ui.js`, `styles.css`, `index.html`, `stub/`, `build_tool.R`. |
| `tests/` | `run_tests.R` and its helpers. |
| `app/` | Daily job `job.R`, Pages build `build_pages.sh`, feeds `build_feeds.py`, `check_dupes.py`, `site_index.html` (landing page at `/`), the Azure-era container files were removed on 2026-11-12 (see git history). |
| `data/raw/` | Untouched inputs (agency plan PDFs, SAM listings, organizer files). |
| `data/manual/` | Hand-authored tables, including the agency goal tables and plan text checks. |
| `data/cache/` | Saved API, OCR and model responses so reruns are free. |
| `data/processed/` | Pipeline outputs, including the tracked `payload.json` snapshot. `items.csv` and `ranking.csv` are git-ignored. |
| `data/example/` | Toy data used only when real files are missing. |
| `data/qualifier/` | The two qualifier-round files the pipeline still reads (see its README). |
| `data/label_check/` | Held-out label check inputs and results read by `R/40_label_check.R`. The labeler sheets, hidden keys and `holdout/label_check_items.csv` are not tracked (local only, see the publishing checklist). |
| `docs/` | Runbook, pipeline guide, fact sheet, payload contract (`contract.md`), real-app criteria, daily job, expansion plan, requirements, pilot plan, handover, this map, publishing checklist. |
| `outs/` | Generated outputs (git-ignored except `.gitkeep`). |
| `archive/` | Historical, not used by the pipeline. See `archive/README.md`. |
| `R/helpers_research.R`, `R/14_build_research_payload.R` | Researcher tab: parsers and pool rule, and the script that writes `research.json`. |
| `R/15_build_research_testset.R` | Builds the award test set files in `data/research_testset/`. |
| `R/02f_research_pool.R` | Optional refresh of the researcher pool from Simpler.Grants.gov (needs a key; not run in phase 1). |
| `data/manual/nih_ic_codes.csv` | Known NIH institute codes used to read the funder from opportunity numbers. |
| `data/processed/research.json` | Researcher tab data snapshot (dated). |
| `data/research_testset/` | Award test set for the researcher tab (10 of 20 awards so far). |
| `tests/test_research.R`, `tests/research/` | R tests for the parsers; Node unit tests and test-set scorer for the tab. |
| `tool/research/` | Researcher tab code: `research_core.js`, `research_tab.js`, `research.css`, `synonyms.json`. |
| `docs/research_testset_results.md` | First test-set run, recorded without a pass bar. |
| `docs/superpowers/` | Design spec and implementation plan for the researcher tab. |
| `.github/` | Workflows (`pages.yml`, `checks.yml`, `freshness.yml`) and the feedback issue template. |

## Old to new paths

| Before | Now |
|---|---|
| `Finalists/src/R`, `src/tool`, `src/tests` | `R/`, `tool/`, `tests/` |
| `Finalists/app` | `app/` (Azure scripts `deploy_azure.sh`, `make_snapshot.sh`, `stage_proof_assets.sh` to `archive/azure_era/`) |
| `Finalists/data/{raw,manual,cache,processed,example}` | `data/...` |
| `Finalists/src/docs/*.md` | `docs/` (`azure_setup`, `organizer_materials_notes`, `qa_cheatsheet` to `archive/finalists/docs/`) |
| `Finalists/src/docs/*.csv` | `data/manual/` |
| `Finalists/saturday/03_contract.md` | `docs/contract.md` |
| `Finalists/README.md` | `docs/pipeline.md` |
| `Finalists/AI_USAGE_LOG.md`, `.claude/improvement-log.md` | `AI_USAGE_LOG.md`, `docs/improvement-log.md` |
| `Finalists/drafts/claude/{eval,docs/holdout}` | `data/label_check/{eval,holdout}` |
| `Finalists/src/data/cache/llm` (misplaced) | `archive/finalists/misplaced_llm_cache/` |
| `QualifierChallenge/data/manual/agency_capabilities.csv`, `data/processed/payload.json` | `data/qualifier/` |
| `QualifierChallenge/data/cache/api/nc_counties_tigris.rds` | not copied: identical to `data/cache/api/nc_counties_tigris.rds` |
| Rest of `QualifierChallenge/`, `Finalists/{planning,saturday,deliverables,testing,outs,FIELD_NOTES.md}` | `archive/` |

## Behavior changes

- The Pages root `/` used to serve the qualifier round's site (`tool.html`, notebook, downloads). It is now a small landing page that forwards to `/matchmaker/`; the old site is in `archive/qualifier/docs/` if the owner wants it back.
- Tier rules: older docs said they live in `tiering.js`. That file belongs to the qualifier tool. In this tool the tier rule is `signature_tier()` in `R/helpers_rank.R`.

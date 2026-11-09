**Layout change (Oct 2026):** the qualifier work now lives in `QualifierChallenge/` (README.md, GUIDE.md, handoff.md, `src/`, `data/`, `outs/`, `docs/`, the .Rproj and .Renviron). All paths below are relative to that folder; run commands from `QualifierChallenge/src/`. The repo's `.git` stays at this level. Round-two work goes in its own subfolder here.

Apply when working anywhere in this folder (Solve-A-Thon 2026, NC's Hidden Treasure; team project, R-based). Read README.md first; GUIDE.md maps every file. Vault hub: ~/Documents/KALNotes/Projects/Competitions/Solveathon.

- Goal: help an NC DHHS grant writer act on Grants.gov opportunities (1,662 in the file). Sorts them into Tier 1-3 by whose signature is needed (writer, supervisor, secretary/legislature) plus Tier 4 (university-led research), checked against the DHHS 2023-2025 plan (DMVA 2025-2029 also used).
- Layout: `src/` = everything written by hand (`solveathon_project.qmd` notebook, `R/` numbered pipeline, `tool/` JS tool source, `docs/` briefs and AI-usage disclosure). `data/` = `raw/` (never modify), `manual/` (hand-authored tables), `cache/` (API and LLM responses), `processed/` (incl. `payload.json`). `outs/` = generated only, safe to delete. `docs/` = GitHub Pages site built by `src/build_site.py`.
- Run: from `src/`, follow the "Rebuild from scratch" block in README.md. Start with `Rscript R/check_facts.R`; it must print "24 of 24 rows pass". Needs R 4.5 and Quarto; no Census key or Ollama needed because caches are committed.
- Conventions: every threshold and default lives in `src/R/00_config.R`. Tier rules live only in `src/tool/tiering.js` (R runs it through V8); never duplicate them. Tool numbers come from `payload.json`, not hard-coded JS.
- Constraints: the LLM only labels requirements with quoted evidence; it never assigns a tier. Presentation numbers must come from the verified facts in `src/docs/presentation_brief.md`. Do not invent figures.
- Do not re-run outside-service scripts (`01a`, `03_llm_label.R`, ACS pull) casually; they call out only for uncached items.
- Do not edit `.Renviron` or `.RData`; keep any API key out of files you write.
- Judging criteria: Understanding (match criteria specific to this agency and user), Framing (problem and requirements), Solving (sensible, reproducible, wanted by an agency), Evaluating (name a real weakness and its tradeoff), Driving Impact (a non-technical budget director knows the next step).
- Deliverables: top results list with rationale, notebook with AI disclosure, 5-minute recorded presentation for agency leadership.
- Current status and open items change often: see `handoff.md`, not this file.

# archive

Historical material from the Solve-A-Thon 2026 competition. It is kept so the project's history and decisions stay readable. **Nothing in here is used by the pipeline, the tests, the workflows or the site build.** Paths inside these files refer to the folder layout at the time (`Finalists/`, `QualifierChallenge/`); they are not updated.

| Folder | What it holds |
|---|---|
| `qualifier/` | The round-one work (NC DHHS grant-writer triage): R pipeline, notebook, tool, caches, data, outputs, its Pages site (`docs/`). The two files the pipeline still reads were copied to `data/qualifier/`. The round-one hand labels (`data/manual/handlabels_60.csv` and its template, which hold labeler initials) are not tracked: they stay on the owner's machine, so the qualifier's `04_validate.R` cannot run from a fresh clone. |
| `finalists/planning/`, `finalists/saturday/` | Discovery notes, framing worksheets, build-day decisions, mentor logs. The payload contract moved to `docs/contract.md`. |
| `finalists/docs/` | Organizer brief, judging rubric, Q&A defense, Azure setup notes, organizer-material notes. |
| `finalists/deliverables/`, `finalists/testing/`, `finalists/FIELD_NOTES.md` | Competition deliverables and simulated reviewer testing notes. |
| `finalists/misplaced_llm_cache/` | 9,724 Ollama responses written to the wrong folder by a labeling run; the committed tarball `data/cache/llm_machineA_2026-11-07.tar.gz` is the copy to resume from. |
| `finalists/outs_figures/` | Backtest figures from the competition. |
| `finalists/OLD_CLAUDE.md`, `finalists/old_*gitignore`, `finalists/report.qmd`, `finalists/_quarto.yml` | Old project instructions, ignore files and the report template. |
| `azure_era/` | Scripts for the Azure Container App deployment, replaced by GitHub Pages. |

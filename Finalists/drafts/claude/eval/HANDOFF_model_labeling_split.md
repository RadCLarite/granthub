# Handoff: model-label the full pool on five machines

Goal: label every open grant (1,576 rows: posted, forecasted, notice) against each agency plan with the local Ollama model. Five machines (A to E) split the work. Plan: `model_labels/agency_plan.csv` (columns agency, machine, order, status). Each finished agency writes its own CSV, so partial results are usable.

## Status (Sat Nov 7, late morning)
- Done, 11 of 34 (`status = done`, files in `model_labels/by_agency/`): Public Schools, Environmental Quality, DHHS, Administration, Agriculture and Consumer Services, Information Technology, Justice (machine A); Adult Correction, Commerce, Insurance, Labor (machine B).
- To do, 23: split A 7, B 4, C 4, D 4, E 4. Machine A is Kent's, the fastest, so it gets the most. Agencies that were in progress stay on the same machine (Military and Veterans Affairs on A, Natural and Cultural Resources on B) so local caches are reused. The rest are ordered by likely grant volume (a judgment, not measured); "Guiding Principles" and "State Board of Education Plan" are plan-level, not agencies, so they go last.

## Who runs which letter (Kent fills this in before announcing)
| Machine | Person | Agencies |
|---|---|---|
| A | Kent | 7 |
| B | (whoever ran machine B before) | 4 |
| C | | 4 |
| D | | 4 |
| E | | 4 |

## Read first
- The validation gate FAILED (in-sample kappa 0.44; held-out check also failed, and the two human labelers agreed at kappa 0.32). Runs use `force=1`. Every number built on these labels must say "model labels, unvalidated". These labels never enter the ranking score.
- Prompt is fixed at `evalpool-v3`, model `qwen2.5:14b`. Do NOT edit the prompt, `MAX_TEXT_CHARS` or the model; labels from different prompts or models cannot be mixed.
- Do not `git pull` a newer `data/processed/opportunities.csv` mid-run. The script now stops if the pool differs from the finished labels.

## Time (measured, not promised)
About 3.3 s per item on Kent's machine (qwen2.5:14b, one process); one agency is 1,576 items, so about 1.5 to 2 hours on Kent's machine and likely longer on smaller laptops [uncertain, not measured on C to E]. Run one process per machine: parallel processes did not help (the GPU is the limit). Labels will not be ready before the 6:00 pm build stop for every agency; they are not in the demo. Whatever finishes by the cutoff is the result.

## Setup (machines B to E; about 20 minutes)
Needs about 10 GB disk and 16 GB RAM. With 8 GB RAM the model will not load: tell Kent instead of switching to a smaller model.
1. Get the repo: `git fetch origin` then `git switch main` and `git pull`. Run everything from the `Finalists` folder.
2. Install R 4.5 packages: data.table, openxlsx, httr2, jsonlite, digest, dplyr, stringr, purrr, tibble, here.
3. Install Ollama (ollama.com), then `ollama pull qwen2.5:14b`.
4. Check: `ollama list` shows `qwen2.5:14b`.
5. Keep the laptop plugged in and awake (macOS: run the label command under `caffeinate -i`).

## Run (replace X with your letter)
```bash
caffeinate -i Rscript drafts/claude/eval/model_label.R stage=full force=1 machine=X
```
It prints how many agencies are yours and how many are already done, then one progress line every 10 items. If it stops, run the same command again: finished agencies are skipped and the LLM cache resumes the rest. On Windows or Linux drop `caffeinate -i`.

## Send results back
After each agency finishes (a file appears in `drafts/claude/eval/model_labels/by_agency/`):
1. `git switch -c <yourname>/labels-<X>` (first time only; later just stay on it).
2. `git add drafts/claude/eval/model_labels/by_agency/*.csv` (only those files; never `*.csv.tmp`, never `src/data/cache/llm/`).
3. `git commit -m "Model labels, machine X: <agency>"` then `git push -u origin <yourname>/labels-<X>`.
4. Tell Kent. He merges. File names are agency slugs, so machines never collide.

## Merge (any machine, from Finalists)
```bash
Rscript -e 'library(data.table); f <- list.files("drafts/claude/eval/model_labels/by_agency", "\\.csv$", full.names=TRUE); d <- rbindlist(lapply(f, fread, colClasses=list(character=c("opp_id","opp_number")))); fwrite(d, "drafts/claude/eval/model_labels/full_pool_labels.csv"); print(d[, .N, by=.(agency, model_label)][order(agency, model_label)])'
```

## Output columns
agency, opp_id, opp_number, title, model_label (relevant | maybe | not relevant), evidence (an exact quote from the notice, or NA), evidence_ok (the quote was found in the text; labels without a verifiable quote are forced to "not relevant"), cached.

## Do not
- Edit the prompt, the model or `MAX_TEXT_CHARS`.
- Commit `src/data/cache/llm/` or push to `main`.
- Use these labels as ground truth or quote them as validated.
- Add AI-use entries to `AI_USAGE_LOG.md` by hand on machines B to E; tell Kent so one entry covers all machines.

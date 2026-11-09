# Saturday Nov 7: start here

Team **Wasian**. Presenting Sun Nov 8, **10:26 to 10:34 am** (6 min with demo, 2 min Q&A). Submission closes Sun **9:00 am**.

This folder is the plan for Saturday. It overrides `planning/08_saturday_plan.md`, `planning/09_tool_plan_update.md` and `planning/08_product_decisions.md` where they differ. Where this folder says nothing, 09 applies, then 08 plus amendments A to L.

## If you are a teammate's Claude
1. Read this file.
2. Read your person's brief in `people/<name>.md` (kent, marco, everett, noah, matthew). Start on its first unchecked step.
3. Read `03_contract.md` before writing any file. It says which files you own and the shape of `payload.json`.
4. Read `06_dependencies.md` so you know who waits on you and what you wait on.
5. Read other files here only when your brief points to them.

Rules that apply all day:
- Edit only the files your brief says you own. Need a change in someone else's file? Write it in your brief's "Handoff" section and tell your person to tell the owner.
- Do not edit `src/R/00_config.R`. Put any new setting at the top of your own script, marked `# TODO move to 00_config.R`, and list it in your Handoff section. Kent moves it at the merge.
- Work on a branch named `<name>/sat-<topic>` (for example `everett/sat-backtest`). Commit and push that branch. Never commit to `main`, never merge, never force-push. Kent merges only at the merge windows in `00_timeline.md`.
- Numbers on slides or in docs come only from `src/docs/fact_sheet.md`. Never invent a number, source or quote. Write "not found".
- An LLM labels with a quote; it never decides. Award history never goes into the score.
- Log every AI use in `AI_USAGE_LOG.md`.
- Stuck more than 20 minutes, or any merge conflict: stop and tell your person to message Kent.

## Files here
| File | What it holds |
|---|---|
| `00_timeline.md` | Hour by hour, Saturday and Sunday morning, merge windows, mentor slots |
| `01_goals.md` | What "done" means at 1:00 and at 6:00, cut order, never-cut list |
| `02_decisions.md` | The 12 decisions Kent locked Sat (1 to 10 at ~1 am, 11 and 12 later), with reasons |
| `03_contract.md` | File ownership, branch names, `payload.json` and backtest file schemas |
| `04_mentor_questions.md` | Questions per mentor and slot, plus how to log answers |
| `05_open_questions.md` | Things still undecided or unverified, and who answers them |
| `prompts.md` | The exact first message each person sends to their AI at 8:30 |
| `06_dependencies.md` | Who waits on whom, by when, and what happens if it is late |
| `mentor_log.md` | Matthew fills it during mentor slots |
| `people/*.md` | One brief per person: goal, owned files, steps with times, done means, handoff |

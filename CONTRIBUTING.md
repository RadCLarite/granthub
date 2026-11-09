# Contributing

Thanks for helping. This file is for people changing the code, data or docs. If you only use the tool, see [README.md](README.md). By taking part you agree to the [code of conduct](CODE_OF_CONDUCT.md). Contributions are accepted under the Apache License 2.0 ([LICENSE](LICENSE)).

## Report a problem without coding

Use the repository's Issues tab and the "Matchmaker feedback" form. Issues are public. Do not put keys, names, contact details or anything about real people in them. For security or privacy problems, follow [SECURITY.md](SECURITY.md).

## One-time setup

1. Install [Git](https://git-scm.com/downloads) and [R 4.5](https://cran.r-project.org/). [Quarto](https://quarto.org/docs/get-started/) is needed only to render reports. Python 3 is needed for the site build and the duplicate-function check.
2. Fork or clone the repository and enter it. The clone is large (data caches are committed), so give it a minute.
3. Install the R packages listed under "Quick start" in [Finalists/README.md](Finalists/README.md).
4. Check it works. From `Finalists/src`:
   ```bash
   Rscript tests/run_tests.R     # expect "89 of 89 tests pass"
   Rscript R/check_facts.R       # expect "49 of 49 rows pass"
   ```
   From the repository root: `python3 Finalists/app/check_dupes.py` (must pass), and `sh Finalists/app/build_pages.sh <outdir> Finalists/data/processed/payload.json` to build the site.
   No API keys or network are needed: caches are committed.

Read [Finalists/README.md](Finalists/README.md) first, then [Finalists/src/docs/runbook.md](Finalists/src/docs/runbook.md) if you will run or fix the daily job.

## Workflow

Never push straight to `main`. Use a branch and a pull request.

```bash
git checkout main && git pull
git checkout -b short-topic            # e.g. fix-deadline-parsing
# ...edit, run, test...
git add <files you changed>
git commit -m "Short description of the change"
git push -u origin short-topic
```

Open a pull request on GitHub. Say what changed, why, and which checks you ran. A maintainer reviews and merges.

## Rules that keep the project working

- Run R commands from `Finalists/src/`.
- Every threshold and default lives in `Finalists/src/R/00_config.R`. Tier rules live only in `Finalists/src/tool/tiering.js` (R runs it through V8). Do not copy them elsewhere.
- The model never sets rank, eligibility or tier. A language model may only label text with a quoted piece of evidence.
- Numbers quoted in the tool or docs come from `Finalists/src/docs/fact_sheet.md` and `Finalists/data/manual/facts.csv`. Do not invent figures; if a number changes, change the fact and its reason.
- Do not edit files in `Finalists/data/raw/`. Hand-written tables go in `Finalists/data/manual/`.
- Do not re-run scripts that call outside services (the `02*` fetch scripts, `03_llm_label.R`, the ACS pull) casually. They contact outside services for uncached items and some need keys.
- No API keys, `.Renviron`, `.RData` or `.Rproj.user/` in commits. Keys belong in your own environment. Do not commit files over 50 MB.
- Before opening a pull request, the checks above must pass. Say in the pull request if you regenerated large generated files.
- Do not add names, emails, phone numbers or private notes to the repository. Internal team notes are kept out of the public tree (see `.gitignore`).
- If you use an AI tool to produce something that ends up in the project, add a row to [Finalists/AI_USAGE_LOG.md](Finalists/AI_USAGE_LOG.md).

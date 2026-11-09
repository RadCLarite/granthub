# Contributing

Thanks for helping. This file is for people changing the code, data or docs. If you only use the tool, see [README.md](README.md). By taking part you agree to the [code of conduct](CODE_OF_CONDUCT.md). Contributions are accepted under the Apache License 2.0 ([LICENSE](LICENSE)).

## Report a problem without coding

Use the repository's Issues tab and the "Matchmaker feedback" form. Issues are public. Do not put keys, names, contact details or anything about real people in them. For security or privacy problems, follow [SECURITY.md](SECURITY.md).

## One-time setup

1. Install [Git](https://git-scm.com/downloads) and [R 4.5](https://cran.r-project.org/). [Quarto](https://quarto.org/docs/get-started/) is needed only to render reports. Python 3 is needed for the site build and the duplicate-function check.
2. Fork or clone the repository and enter it. The clone is large (data caches are committed), so give it a minute.
3. Install the R packages listed under "Quick start" in [docs/pipeline.md](docs/pipeline.md).
4. Check it works. From the repo root:
   ```bash
   Rscript tests/run_tests.R     # expect every test to pass (zero failures)
   Rscript R/check_facts.R       # expect "49 of 49 rows pass"
   ```
   From the repository root: `python3 app/check_dupes.py` (must pass), and `sh app/build_pages.sh <outdir> data/processed/payload.json` to build the site.
   No API keys or network are needed: caches are committed.

Read [docs/pipeline.md](docs/pipeline.md) first, then [docs/runbook.md](docs/runbook.md) if you will run or fix the daily job.

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

- Run R commands from the repo root.
- Every threshold and default lives in `R/00_config.R`. Tier rules live only in `signature_tier()` in `R/helpers_rank.R`. Do not copy them elsewhere.
- The model never sets rank, eligibility or tier. A language model may only label text with a quoted piece of evidence.
- Numbers quoted in the tool or docs come from `docs/fact_sheet.md` and `data/manual/facts.csv`. Do not invent figures; if a number changes, change the fact and its reason.
- Do not edit files in `data/raw/`. Hand-written tables go in `data/manual/`.
- Do not re-run scripts that call outside services (the `02*` fetch scripts, `03_llm_label.R`, the ACS pull) casually. They contact outside services for uncached items and some need keys.
- No API keys, `.Renviron`, `.RData` or `.Rproj.user/` in commits. Keys belong in your own environment. Do not commit files over 50 MB.
- Before opening a pull request, the checks above must pass. Say in the pull request if you regenerated large generated files.
- Do not add names, emails, phone numbers or private notes to the repository. Internal team notes are kept out of the public tree (see `.gitignore`).
- If you use an AI tool to produce something that ends up in the project, add a row to [AI_USAGE_LOG.md](AI_USAGE_LOG.md).

# grantHub: Federal Funds Matchmaker

A free tool that helps a North Carolina state agency grant coordinator see which open federal grants fit the agency's own strategic plan, early enough to apply. You pick your agency. The tool lists the best-fitting open opportunities, says why each one matched, and shows when it closes.

It started as an entry in the Solve-A-Thon 2026 challenge for the NC Office of State Budget and Management (OSBM). It is an independent project, not an official OSBM or agency product (see [NOTICE](NOTICE)).

## Where to open it

**Live link: not set yet.** The tool is a static web page built by GitHub Pages, and the public address has not been confirmed. Until it is, a maintainer can build the site locally; the steps are in the [runbook](docs/runbook.md). When the address is set, it will be put here.

## How to use it

1. Open the tool and pick your agency.
2. Read the Top 10 list. Each row shows the grant, the award size if listed, days left to apply, and a one-line reason it matched your agency's plan.
3. Check "Coming up" (forecasted grants not yet open) and "Hidden" (grants the tool thinks your agency cannot receive, with the reason, so you can disagree).
4. Mark grants Pursue, Maybe or Skip, and add notes. Your marks stay in your browser.
5. Export your list as a file when you are done. Open the grant's own page on Grants.gov for the real eligibility rules and deadline before you act.

## What it is not

- It is a screening aid, not a decision. A person decides what to pursue, and eligibility must be confirmed on the notice itself.
- It does not predict whether you will win. Some cards show a rough "our estimate" chip that looks only at how many awards are expected and who may apply. It is labeled as an estimate and is not a measured chance.
- It does not apply for anything, and it does not replace your grants office, your budget office or the funder's contact.
- It does not yet fetch new postings by itself (see below).

## For researchers

The "For researchers" tab lists open federal opportunities that a university or nonprofit applicant can apply to, with a search box, filters and a time warning. It is a screening aid: it helps you decide what to read, and the Grants.gov notice is the authority on dates, eligibility and fit. "Unknown" means unknown: when a mechanism, institute, trial status or date could not be read from the notice, the tab says so and does not guess.

Ranking is keyword matching (BM25) with a synonym list. Each result shows the terms that matched, so you can see why it ranked where it did. Words that appear next to each other in a listing rank higher, and a phrase in double quotes is required (quotes count in a short search, not in a pasted abstract). The search runs in your browser on data files from this site (`research.json`, `synonyms.json`); what you type is not sent anywhere. The one exception is the optional ORCID lookup: after you click "Look up my papers" the tab sends only your ORCID iD to OpenAlex (`api.openalex.org`) and reads your public papers; nothing is stored. OpenAlex is used without a key, so a free daily limit is shared by everyone on your network; if it is used up the tab says so and you paste an abstract instead. A key must never be put in this site, because a key in a public page is visible to everyone.

Each card can show "Mentioned" flags read from the notice text (letter of intent, foreign participation allowed, cost sharing, subaward, multiple PIs, IND or IDE, data sharing, animal research, human subjects). Absence of a flag means unknown, not no. A "My project has..." checklist in Filters highlights the matching flags and tells you when a listing does not say. Static Atom and calendar feeds per NIH institute are under `feeds/research/`, and the results list has a button that downloads its deadlines as a `.ics` file.

Run the checks from the repo root with `node tests/research/test_core.js` (unit tests) and `node tests/research/run_testset.js` (scores the award test set against all rows, against posted (active) rows only and against forecasted rows only, and writes `outs/research_testset_report.csv` plus `_posted.csv` and `_forecasted.csv`).

Rebuilding `research.json` (from the repo root, in this order; it is a manual step, not part of the daily job):

1. `Rscript R/02f_research_pool.R` pulls the open pool from Simpler.Grants.gov into `data/processed/research_opportunities.csv`. It calls an outside service and needs `SIMPLER_GRANTS_KEY` in your `.Renviron` (never in a tracked file); pages already in `data/cache/api/simpler_research/` are not fetched again.
2. `Rscript R/02g_research_unmatched.R` looks up post date, cost sharing and the grants.gov link for pool rows that `opportunities.csv` does not hold, one read-only Grants.gov call per row, cached in `data/cache/api/grantsgov_detail/`. It reads the file from step 1, so run it second. It writes `data/processed/research_grantsgov_lookup.csv`.
3. `Rscript R/14_build_research_payload.R` writes `data/processed/research.json`. It takes post date, cost sharing, eligibility text and the grants.gov link from `opportunities.csv` and the step 2 lookup (Simpler has none of them), then fits the file to the size budget: if it is over `RESEARCH_PAYLOAD_BUDGET` (1,850,000 bytes) it cuts every summary to a common length, in 100-character steps from 1,200 down to a floor of `RESEARCH_SUM_FLOOR` (600), and says so. It stops if the floor does not fit or the file passes `RESEARCH_PAYLOAD_LIMIT` (2,000,000 bytes). The three numbers are in `R/00_config.R`.
4. `node tests/research/run_testset.js`, then `node tests/research/test_core.js`, `python tests/research/test_feeds.py` and `Rscript tests/run_tests.R`. Compare the test-set summary with `docs/research_testset_results.md` before committing.

Only step 1 needs a key, and only steps 1 and 2 call outside services. This does not refresh `opportunities.csv`; that is `R/02a`, `02b` and `03`, which need `REF_DATE` moved in `R/00_config.R`; that invalidates the 02b and 02e cache keys, so do it on its own branch.

Current limits:
- Only R01, R21 and K-family mechanisms have lead times, and forecasted or no-close rows get no deadline check. On the current data (1,426 rows, checked for 2026-11-10) 144 rows (10.1%) get an ok, tight or late time warning; the rest show "unknown" (no parsed mechanism, or a mechanism with no lead time) or "date not announced".
- The tab shows when the listings were fetched and warns when they are 3 or more days old; research.json is rebuilt by hand, not by the daily job.
- Funder (institute) codes are known for only about 16% of the pool (224 of 1,426), and a mechanism for about 38% (536).
- The test set has 10 of 20 awards. The owner adds 10 more of their own.
- Lead times behind the time warning are estimates, not agency commitments.

## Who maintains it

No maintainer or owner is named yet. The [runbook](docs/runbook.md) is written for whoever takes it on and has an owner line still to fill in.

## How the data refreshes

A daily GitHub Actions job re-scores the opportunity data already stored in the repository, rebuilds the site and redeploys it. It does not fetch new postings from Grants.gov. Fetching new postings is still a manual step run by a person with the needed API keys. So the list shows the grants gathered at the last manual fetch, minus any whose close date has since passed. The tool shows a "data as of" date, and a banner when the data is 3 or more days old. These workflows have not yet run on GitHub, so the daily refresh is unverified in production.

## Privacy

The tool is a static page. It loads its data files (the grant payload and, for the researcher tab, research.json and synonyms.json) from its own site; the only other request is the researcher tab's optional ORCID lookup to api.openalex.org, sent only when you click Look up and carrying only your ORCID iD; your agency choice, marks and notes are kept in your browser's local storage on your device and are never sent anywhere. There are no accounts. Links in the tool (Grants.gov, SAM.gov, the feedback link) open other sites only when you click them. Clear your browser's site data to erase your marks.

## Report a problem or give feedback

Open the repository's **Issues** tab, choose **New issue**, and use the "Matchmaker feedback" form. Issues are public: do not include names, contact details, keys or anything about real people. Grant and agency names are fine. For a security or privacy problem, follow [SECURITY.md](SECURITY.md) instead.

## For developers

| You want | Open |
|---|---|
| What the pipeline does, how to run it and extend it | [docs/pipeline.md](docs/pipeline.md) |
| Running, rerunning and fixing the daily job and site | [docs/runbook.md](docs/runbook.md) |
| Setup, branches and rules for contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Every number the tool quotes, with the script that reproduces it | [docs/fact_sheet.md](docs/fact_sheet.md) |
| Where the data comes from | [NOTICE](NOTICE) and [data/raw/README.md](data/raw/README.md) |
| Record of how AI tools were used in building this | [AI_USAGE_LOG.md](AI_USAGE_LOG.md) |

Folders: `R/` (pipeline), `tool/` (the web page), `tests/`, `app/` (daily job and site build), `data/`, `docs/`, and `archive/` (historical competition material, not used by the pipeline). The full map is in [docs/REPO_MAP.md](docs/REPO_MAP.md).

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

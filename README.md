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

## Who maintains it

No maintainer or owner is named yet. The [runbook](docs/runbook.md) is written for whoever takes it on and has an owner line still to fill in.

## How the data refreshes

A daily GitHub Actions job re-scores the opportunity data already stored in the repository, rebuilds the site and redeploys it. It does not fetch new postings from Grants.gov. Fetching new postings is still a manual step run by a person with the needed API keys. So the list shows the grants gathered at the last manual fetch, minus any whose close date has since passed. The tool shows a "data as of" date, and a banner when the data is 3 or more days old. These workflows have not yet run on GitHub, so the daily refresh is unverified in production.

## Privacy

The tool is a static page. It loads one data file from its own site and nothing else; your agency choice, marks and notes are kept in your browser's local storage on your device and are never sent anywhere. There are no accounts. Links in the tool (Grants.gov, SAM.gov, the feedback link) open other sites only when you click them. Clear your browser's site data to erase your marks.

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

# Publishing checklist (owner actions before the repository goes public)

Nothing here has been done. The repository has no remote and has not been pushed. Tick each item before the first push.

## Create and configure
- [ ] Create the GitHub repository and add it as `origin`. Push `main` only after the items below are decided.
- [ ] Settings > Pages > Source: **GitHub Actions**.
- [ ] Set the repository variable `SITE_URL` (Settings > Variables) to the real Pages address, with the `/matchmaker/` path. `freshness.yml` falls back to `https://kapollol.github.io/granthub/matchmaker/`.
- [ ] Replace the assumed repository address `KApolloL/granthub` (and `kapollol.github.io/granthub`) where it appears: `.github/workflows/freshness.yml`, `app/build_feeds.py` (`SITE`), `tool/matchmaker.html` (`FEEDBACK_ISSUE`), `.github/ISSUE_TEMPLATE/feedback.yml` if it links back, `docs/pipeline.md`, `docs/runbook.md`, `docs/improvement-log.md`. Search with `git grep -i kapollol`.
- [ ] Run the "Deploy site to GitHub Pages" workflow once by hand and read any failure. None of the workflows has run on GitHub yet.
- [ ] Turn on "Report a vulnerability" (Security tab) so `SECURITY.md` works, and name a contact in `SECURITY.md`.

## People and ownership
- [ ] Name an owner and a backup (`docs/runbook.md` line 3, README "Who maintains it").
- [ ] Decide who gets the failed-run emails (GitHub emails repository owners about failed scheduled runs).

## Keys and secrets
- [ ] Rotate every key that was ever used on the team machines (Simpler.Grants.gov, SAM.gov, any Azure or model key). The tracked tree has no key file, but keys were held in `api_keys.env` and `.Renviron` outside git.
- [ ] Decide what happens to the Azure resources named in `archive/finalists/docs/azure_setup.md` and `app/` (registry, storage, container app). Remove the names from the public tree if the resources will be deleted or should not be advertised.

## Third-party requests from the browser
- [ ] The researcher tab calls one outside host, `https://api.openalex.org`, only after a click on "Look up my papers", sending only the ORCID iD (no cookies, nothing stored). Confirm the notice text above the ORCID box still says this.
- [ ] OpenAlex runs without a key (observed 2026-11-10: a free daily budget shared per IP address). Never commit an OpenAlex key; a key in a public static page is visible to everyone. If the owner later wants a key, put it behind a proxy the owner controls.

## Personal and third-party data in the tree
- [ ] Contact emails in data: opportunity records (`data/processed/opportunities.csv`, `.json`, `payload.json`, `grantsgov_extract.csv`, `sam_listings.csv`) and cache JSON under `data/cache/api/` carry federal program contact addresses (for example `support@grants.gov`, agency grant offices). They are public notice contacts, but decide whether to strip them. Some agency plan text files under `data/processed/agency_plan_text/` contain staff addresses from the PDFs.
- [ ] UNC email addresses: present in `archive/finalists/` (Azure setup, organizer notes, planning, deploy checklist). Remove or redact before publishing, or drop those files from `archive/`.
- [ ] `data/label_check/`: hand-label sheets with labeler identifiers (`eval/sheets/`, `holdout/holdout_labeler_*.csv`) and hidden answer keys (`eval/sheets/key_hidden_DO_NOT_SHARE.csv`, `holdout/holdout_key_DO_NOT_OPEN.csv`). Publishing the keys defeats any future blind labeling. Decide to keep, anonymize, or move to `archive/` (then update `R/40_label_check.R`, which reads them).
- [ ] `data/raw/organizer/`: organizer-supplied files (starter kit, Azure access guide, presentation template, `additional-tools*`). They are third-party and may be confidential or copyrighted. Get permission or remove them; update `data/raw/README.md`.
- [ ] `data/raw/agency_plans/` PDFs and `data/raw/sam_assistance_listings/`: public sources; confirm the licence notes in `NOTICE` and `data/raw/README.md` are complete.
- [ ] `archive/qualifier/` (about 7,600 cached files and the qualifier's CDC mortality extract under `archive/qualifier/data/raw/`): confirm redistribution is fine, or keep it out of the public repository.
- [ ] Names in `AI_USAGE_LOG.md`, `docs/contract.md`, `docs/improvement-log.md` and `archive/`: confirm the team agrees to be named.

## Repository hygiene
- [ ] Repository size: the tree has about 17,500 archived files and many cache files. Consider Git LFS or dropping `archive/finalists/misplaced_llm_cache/` (9,724 loose files duplicated by the tarball in `data/cache/`).
- [ ] Decide whether to keep the Azure-era files that remain in `app/` (`Dockerfile`, `Dockerfile.job`, `entrypoint.sh`, `app.R`, `read_feedback.sh`, `pilot_scorecard.sh`). `Dockerfile` copies `app/data` and `app/www`, which do not exist.
- [ ] Re-run `Rscript tests/run_tests.R`, `Rscript R/check_facts.R`, `python app/check_dupes.py` on the pushed copy, and open the Pages site at 1280 and 375 px.
- [ ] The Pages root `/` is now a landing page forwarding to `/matchmaker/`; the old qualifier site is in `archive/qualifier/docs/`. Restore it only if the owner wants it live.

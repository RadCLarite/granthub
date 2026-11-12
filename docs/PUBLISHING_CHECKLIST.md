# Publishing checklist (owner actions before the repository goes public)

The repository is public at https://github.com/RadCLarite/granthub and the site is live at https://radclarite.github.io/granthub/matchmaker/. Items below are ticked where checked on 2026-11-12; the rest are open. Each open item ends with **Decides:** the person who has to make the call (assumed from the roles in `AI_USAGE_LOG.md` and `docs/contract.md`; change it if wrong).

## Create and configure
- [x] Create the GitHub repository and add it as `origin`. Done: `origin` is RadCLarite/granthub. (It was pushed with the items below still open, so the open ones are now exposure, not pre-publication tasks.)
- [x] Settings > Pages > Source: **GitHub Actions**. Done (build type is workflow).
- [x] Set the repository variable `SITE_URL` (Settings > Variables) to the real Pages address, with the `/matchmaker/` path. `freshness.yml` now falls back to the real address, so leaving the variable unset is harmless.
- [x] Replace the assumed repository address `KApolloL/granthub` (and `kapollol.github.io/granthub`) where it appears: `.github/workflows/freshness.yml`, `app/build_feeds.py` (`SITE`), `tool/matchmaker.html` (`FEEDBACK_ISSUE`), `.github/ISSUE_TEMPLATE/feedback.yml` if it links back, `docs/pipeline.md`, `docs/runbook.md`, `docs/improvement-log.md`. Search with `git grep -i kapollol`. Done outside `archive/`; `archive/finalists/` and `archive/qualifier/` still carry the old address in historical files (leave them, they are records).
- [x] Run the "Deploy site to GitHub Pages" workflow once by hand and read any failure. Done: it has run on push and on schedule, and succeeded.
- [ ] Turn on "Report a vulnerability" (Security tab) so `SECURITY.md` works, and name a contact in `SECURITY.md`. Open: private reporting is off and `SECURITY.md` names no contact. **Decides:** Kent (owner) switches it on in Settings and gives the contact.

## People and ownership
- [ ] Name an owner and a backup (`docs/runbook.md` line 3, README "Who maintains it"). Open: both say not yet named. **Decides:** Kent.
- [ ] Decide who gets the failed-run emails (GitHub emails repository owners about failed scheduled runs). Open. **Decides:** Kent.

## Keys and secrets
- [ ] Rotate every key that was ever used on the team machines (Simpler.Grants.gov, SAM.gov, any Azure or model key). The tracked tree has no key file, but keys were held in `api_keys.env` and `.Renviron` outside git. Open; two keys are also in the old repo's history. **Decides:** each key holder rotates their own; Kent confirms when done.
- [x] Remove the Azure resource names from the public tree. Done 2026-11-12: names are placeholders (`<registry>`, `<storage-account>` and so on) in 21 files, and `tests/research/test_no_azure_names.py` fails CI if one comes back. The same placeholders replace the names in past `AI_USAGE_LOG.md` rows.
- [ ] Decide whether to delete the live Azure resources (registry, storage, container app, OpenAI resource) and stop the spend. Open. **Decides:** Kent (and whoever owns the Azure subscription).

## Third-party requests from the browser
- [x] The researcher tab calls one outside host, `https://api.openalex.org`, only after a click on "Look up my papers", sending only the ORCID iD (no cookies, nothing stored). Confirmed 2026-11-12: the notice in `research_tab.js` says it sends only the ORCID iD, stores nothing and keeps pasted text on the page.
- [x] OpenAlex runs without a key (observed 2026-11-10: a free daily budget shared per IP address). Never commit an OpenAlex key; a key in a public static page is visible to everyone. If the owner later wants a key, put it behind a proxy the owner controls. Standing rule, nothing to do now.

## Personal and third-party data in the tree
- [ ] Contact emails in data: opportunity records (`data/processed/opportunities.csv`, `.json`, `payload.json`, `grantsgov_extract.csv`, `sam_listings.csv`) and cache JSON under `data/cache/api/` carry federal program contact addresses (for example `support@grants.gov`, agency grant offices). They are public notice contacts, but decide whether to strip them. Some agency plan text files under `data/processed/agency_plan_text/` contain staff addresses from the PDFs. Open. **Decides:** Kent.
- [x] UNC email addresses: four personal addresses redacted in `archive/finalists/` (PR 32). The generic `ONYEN@ad.unc.edu` placeholder stays. `archive/qualifier/` and `archive/azure_era/` have none. Not covered: addresses inside compressed files, and non-UNC personal addresses. They remain in git history.
- [ ] `data/label_check/`: hand-label sheets with labeler identifiers (`eval/sheets/`, `holdout/holdout_labeler_*.csv`) and hidden answer keys (`eval/sheets/key_hidden_DO_NOT_SHARE.csv`, `holdout/holdout_key_DO_NOT_OPEN.csv`). Publishing the keys defeats any future blind labeling. Decide to keep, anonymize, or move to `archive/` (then update `R/40_label_check.R`, which reads them). Open. **Decides:** Kent.
- [ ] `data/raw/organizer/`: organizer-supplied files (starter kit, Azure access guide, presentation template, `additional-tools*`). They are third-party and may be confidential or copyrighted. Get permission or remove them; update `data/raw/README.md`. Open. **Decides:** the Solve-A-Thon organizers give permission; Kent removes if refused.
- [ ] `data/raw/agency_plans/` PDFs and `data/raw/sam_assistance_listings/`: public sources; confirm the licence notes in `NOTICE` and `data/raw/README.md` are complete. Open. **Decides:** Kent.
- [ ] `archive/qualifier/` (about 7,600 cached files and the qualifier's CDC mortality extract under `archive/qualifier/data/raw/`): confirm redistribution is fine, or keep it out of the public repository. Open. **Decides:** Kent.
- [ ] Names in `AI_USAGE_LOG.md`, `docs/contract.md`, `docs/improvement-log.md` and `archive/`: confirm the team agrees to be named. Open. **Decides:** the team members named.

## Repository hygiene
- [ ] Repository size: the tree has about 17,500 archived files and many cache files. Consider Git LFS or dropping `archive/finalists/misplaced_llm_cache/` (9,724 loose files duplicated by the tarball in `data/cache/`). Open. **Decides:** Kent.
- [x] Remove the Azure-era files from `app/` (`Dockerfile`, `Dockerfile.job`, `entrypoint.sh`, `app.R`, `read_feedback.sh`, `pilot_scorecard.sh`). Done 2026-11-12; they stay in git history. `app/.dockerignore` is now orphaned and was left in place. `app/job.R` stays (the Pages workflow runs it); its upload target now comes from `BLOB_URL`.
- [ ] (CI runs the site build, feed and JS tests on every code PR; the R tests and the visual check are not confirmed here.) Re-run `Rscript tests/run_tests.R`, `Rscript R/check_facts.R`, `python app/check_dupes.py` on the pushed copy, and open the Pages site at 1280 and 375 px. Open. **Decides:** Kent.
- [x] The Pages root `/` is now a landing page forwarding to `/matchmaker/`; the old qualifier site is in `archive/qualifier/docs/`. Restore it only if the owner wants it live. Done, nothing to decide unless the owner wants the old site back.

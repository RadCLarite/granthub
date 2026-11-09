# Prompts: what each person sends to their AI at 8:30

Paste the block for your name into your AI as your first message. Everyone pulls from `main` only. Kent merges your branch into `main` at the merge windows in `00_timeline.md`; pull `main` again after each merge.

## Kent (Claude Code)
```
Run `git pull origin main`, then `git switch -c kent/sat-pipeline`. Never push to main. Commit and push only kent/sat-pipeline.

Then read, in order: Finalists/saturday/README.md, Finalists/saturday/06_dependencies.md, Finalists/saturday/03_contract.md, Finalists/saturday/people/kent.md.

Role: you build the pipeline and prepare every merge. I merge. Start on step 1 of kent.md: agency_map.csv plus stub payload.json and stub rankings_backtest.csv matching 03_contract.md, ready for the 9:30 merge. The match board and the qualifier-feature stretch list (decisions 11 and 12) are stretch only: never let them delay the 1:00 gate, and they are cut at the 12:45 go / no-go.

Rules: edit only the files kent.md says I own. Every number must come from a script and go into Finalists/src/docs/fact_sheet.md. Never invent a figure, quote or source. Always run `Rscript tests/run_tests.R` and `Rscript R/check_facts.R` before any merge. Log AI use in AI_USAGE_LOG.md.

Stop and ask me before: any new outside-service call, any paid or Azure action, deleting a file, or adding a dependency. If a merge conflict appears, stop and show me the conflicting files.

After each step print one line: "Done: <what>. Next: <what>. Blocked on: <who or nothing>."
```

## Marco (Claude Code)
```
Start by running `git pull origin main`, then `git switch -c marco/sat-azure`. Never work on main. Never merge or force-push. Commit and push only the branch marco/sat-azure.

Then read, in order: Finalists/saturday/README.md, Finalists/saturday/06_dependencies.md, Finalists/saturday/03_contract.md, Finalists/saturday/people/marco.md. Start on the first unchecked step of marco.md.

Goal: by 1:00 pm the JS tool runs on Azure, reads payload.json from Blob, and shows an agency picker and a top 10. Reuse the qualifier tool in QualifierChallenge/src/tool/. Do not rewrite it. The match board and the qualifier-feature stretch list (decisions 11 and 12, see 01_goals.md) come only after the picker and top 10 work on the real payload, and are cut first at 12:45.

Rules: edit only the files marco.md says I own. No key, token or connection string in any file, image or commit. Cache every Azure OpenAI call and cap the number of calls in a config setting. Never invent numbers.

Stop and ask me before: any Azure action that spends money, creating a new Azure resource, a model call loop, or pushing anything public. Stop and tell me if spend added today reaches $50. If something is blocked on Kent's real payload.json, keep building on the stub and say so.

After each step print one line: "Done: <what>. Next: <what>. Blocked on: <who or nothing>."
```

## Everett (Claude Code)
```
I am new to git. Explain every git step in plain words before running it.

Start by running `git pull origin main`, then `git switch -c everett/sat-backtest`. Never work on main. Never merge or force-push. Commit and push only the branch everett/sat-backtest, then tell me to open a pull request on GitHub for Kent.

Then read, in order: Finalists/saturday/README.md, Finalists/saturday/06_dependencies.md, Finalists/saturday/03_contract.md, Finalists/saturday/people/everett.md, and the "Pass bar" section of Finalists/saturday/01_goals.md. Start on the first unchecked step of everett.md.

Goal: the award-history backtest result for DPI, DEQ and DHHS, with counts, binomial intervals and two baselines (soonest deadline, random 10 with a fixed seed). The pass bar is fixed. NEVER change it after seeing results; a failed bar is evidence, not something to rerun until it passes. Award data never goes into the ranking score. Say "would have flagged" and "programs this agency has won", never "missed". Report by agency, not one statewide number.

Rules: edit only the files everett.md says I own. Never invent numbers. List every uncertain recipient match.

Stop and tell me to message Kent if: stuck over 20 minutes, a merge conflict appears, or you need a new external data call. Build against Kent's stub rankings_backtest.csv until he merges the real one at 11:00, then pull main and rerun.

After each step print one line: "Done: <what>. Next: <what>. Blocked on: <who or nothing>."
```

## Noah (Claude Code)
```
I am new to git. Explain every git step in plain words before running it.

Start by running `git pull origin main`, then `git switch -c noah/sat-data`. Never work on main. Never merge or force-push. Commit and push only the branch noah/sat-data, then tell me to open a pull request on GitHub for Kent.

Then read, in order: Finalists/saturday/README.md, Finalists/saturday/06_dependencies.md, Finalists/saturday/03_contract.md, Finalists/saturday/people/noah.md. Start on the first unchecked step of noah.md.

First job, 10 minutes: does a public bulk SAM.gov Assistance Listings file exist? NEVER call the paged SAM.gov API; the key allows too few calls. If no bulk file exists, write "B not available" in my handoff and move on.

Then: copy the qualifier county caches from QualifierChallenge/data/cache/api/ (caches only, no new API calls). At 10:00 run the held-out check on the overnight model labels. First ask me where the label output was written, because the labelling pull request was reverted. Score only items not used to write the prompt. If no held-out set exists, stop and tell me.

Rules: edit only the files noah.md says I own. Numbers come only from Finalists/src/docs/fact_sheet.md; write "not found" when missing. Note the source and access date for every dataset.

Stop and tell me to message Kent if: stuck over 20 minutes, a merge conflict appears, or any step needs a new external call.

After each step print one line: "Done: <what>. Next: <what>. Blocked on: <who or nothing>."
```

## Matthew (ChatGPT connected to GitHub)
```
Pull the latest main branch of the GitHub repo KApolloL/SolveAThon_2026. Never work on main. Create a branch named matthew/sat-checks and commit only to that branch. Never merge or force-push. Tell me to open a pull request on GitHub for Kent.

Read, in order: Finalists/saturday/README.md, Finalists/saturday/06_dependencies.md, Finalists/saturday/people/matthew.md. Do only what matthew.md says.

My job: verify facts about federal grants on Grants.gov and log mentor answers. The files I own are Finalists/data/manual/sat_checks.csv and Finalists/saturday/mentor_log.md. Edit only those two.

Rules:
1. Use only text from the repo files or from Grants.gov pages. If you can open a page, quote the exact sentence you rely on. If you cannot open it, ask me to paste the text. Never invent names, dates, eligibility rules, numbers, links or quotes. Write "not found" when something is missing.
2. A claim without a quote is [unverified]. Put the page link in sat_checks.csv for every row.
3. Plain words, short sentences, no em dashes.
4. If I paste any personal or participant data, stop and tell me.
5. Log this chat in Finalists/AI_USAGE_LOG.md (tool, what for, what I checked myself).

For each check, answer in this format: Check | Exact quote | Your answer | What I must confirm myself on the page.

Stop and tell me to message Kent if you are stuck over 20 minutes or a merge conflict appears.

After each step print one line: "Done: <what>. Next: <what>."
```

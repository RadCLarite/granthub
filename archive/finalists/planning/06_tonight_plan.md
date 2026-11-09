# Tonight's plan: Fri Nov 6, 2026

Written at about 6:15 pm. Workshop 6:30 pm, sprint 7:30 to 8:45 pm, mentor check-ins from 8:45 pm.

Related: [docs/QUEST_BRIEF.md](../docs/QUEST_BRIEF.md) (challenge text) | [handoff.md](../handoff.md) (status) | [organizer materials notes](../src/docs/organizer_materials_notes.md) (Starter Kit, Azure guide, template, zip) | [01 discovery questions](01_discovery_questions.md) | [02 framing worksheet](02_framing_worksheet.md) | [05 user criteria and feedback](05_user_criteria_and_feedback.md) | [07 discovery findings](07_discovery_findings.md) | [vault note copies](../_team/vault/README.md) | [agency plans](../data/raw/agency_plans/) and [MANIFEST.csv](../data/raw/agency_plans/MANIFEST.csv)

## Goal for tonight
1. Framing gate ticked ([02_framing_worksheet.md](02_framing_worksheet.md)).
2. Azure: deployed R "hello world" at a public URL, plus one working Azure OpenAI call.
3. Plan-text table for all 34 plans and a top-3 agency shortlist.

Do not analyze opportunity data until the gate is ticked (Deloitte rule). Plumbing is fine.

## Owners
| Person | Job tonight | AI |
|---|---|---|
| Kent | Planning: workshop questions, framing worksheet, gate, first field-notes entry | Claude |
| Marco | All Azure setup, alone | Claude Code (prompt below) |
| Noah and Matthew | Plan text checks | Their own repo-aware AI (prompt below) |
| Everett | Nothing assigned for now | Claude |

Open: nobody is assigned to take verbatim workshop notes. Kent asks questions, so either Everett takes notes or we record the session if the organizers allow it. Decide before 6:30.

## Kent: schedule
- [ ] 6:15 to 6:30: pick who asks which question from [01_discovery_questions.md](01_discovery_questions.md). Add "Should this cover every agency or start with one?" and the questions in [05](05_user_criteria_and_feedback.md), section 7.
- [ ] 6:30 workshop. Capture in the sponsors' own words: the real user and how they find opportunities today; what a good match means (and what they reject, and why); one agency or all first; reaction to the onboarding ranking; what they need to see to fund a pilot; anything that changes our plan (each becomes a dated field-notes entry).
- [ ] 7:30 to 8:45 sprint: fill [02_framing_worksheet.md](02_framing_worksheet.md) (user, problem, key requirements, problem type). Write pass/fail eval targets first (precision@10, recall in top 25, keyword baseline). Decide one-agency-first versus all, with the reason. Tick the gate in [handoff.md](../handoff.md). Write the first field-notes entry.
- [ ] 8:45 mentor check-in: bring the worksheet, Marco's Azure status and the plan-text table. Ask whether R on Container Apps holds and whether Azure OpenAI is ours to use.

---

## Marco: Azure setup

### Steps for Marco
1. Pull the repo. Open Claude Code in the `Finalists/` folder.
2. Install the Azure CLI if `az version` fails (macOS: `brew install azure-cli`). Run `az login`, sign in as `ONYEN@ad.unc.edu`, approve Duo.
3. Paste the prompt below. Approve each `az ... create` when Claude asks.
4. Keep every key and endpoint secret out of the repo and out of chat logs you share. Store keys only in Azure (Container App secrets) or your own shell session.
5. When done, post to the team chat: public URL, region, resource names, and anything that failed. Tell Kent right away if the R image build fights back, because that could change the stack decision.
6. If the subscription does not appear: sign out and back in. Then email Pratik Patekar (patekar@unc.edu), Haihan Gao (hhgao@unc.edu) and Girish Wangikar (girishw@unc.edu), CC all three, with name, team name, subscription name and a screenshot.

### Prompt for Marco (Claude Code)
```text
You are helping me stand up the Azure skeleton for our Solve-a-thon prototype, the "Federal Funds Matchmaker". I am Marco, the team's Azure owner. Work only inside the Finalists/ folder of this repo.

<context>
- Read these first: Finalists/CLAUDE.md, Finalists/src/docs/organizer_materials_notes.md (sections 1 and 2: the organizer Starter Kit design and the Azure Access Guide), Finalists/planning/06_tonight_plan.md.
- Locked decisions: the app is written in R (Shiny for the web UI), not Python. One container image serves two roles via env var MODE=app (web) or MODE=job (daily refresh; a stub is fine tonight). All app state will live as JSON in one Azure Blob container named ffm-data. LLM calls go to Azure OpenAI (an embedding model like text-embedding-3-small and a small chat model like gpt-4o-mini).
- Subscription: the team subscription is named like unc-sdis-solveathon-teamXX. I am already logged in with az login.
- Tonight's goal is a skeleton, not the product. No scoring, no data ingestion, no UI beyond a hello page.
</context>

<task>
1. Run az account list and show me the solveathon subscription. Ask me to confirm before setting it with az account set.
2. Propose a region and resource names (prefix ffm-) in one short table, then wait for my OK. Pick a region where Azure OpenAI and the two models are available; if you cannot confirm availability, say [uncertain] and ask me.
3. Create, one command at a time, asking before each create: resource group; storage account plus blob container ffm-data; Azure OpenAI resource with one embedding deployment and one chat deployment (skip this step if the organizers already provided Azure OpenAI; ask me first); Azure Container Registry (Basic); Log Analytics workspace; Container Apps environment.
4. Test Azure OpenAI with one embedding call and one chat call using curl. Read the key into a shell variable from az, never print it, never write it to a file.
5. Create Finalists/app/ containing a minimal Shiny app (app.R that shows "Federal Funds Matchmaker: hello from Azure" and the value of MODE) and a Dockerfile based on a pinned rocker/shiny image tag. Build it in the cloud with az acr build so I do not need Docker locally.
6. Deploy it as a Container App with external ingress on port 3838, pulling from the registry. Return the public URL and confirm it loads with curl.
7. Write Finalists/src/docs/azure_setup.md: region, every resource name and type, the URL, the exact az commands you ran (with secrets replaced by placeholders like $AOAI_KEY), test results, what failed and how it was fixed, and open questions. No keys, connection strings or tokens.
</task>

<constraints>
- NEVER write a key, token, connection string or password to any file, commit, or chat output. Use env var names as placeholders.
- Stop and ask before: any az create or delete, any role assignment, changing an existing resource, installing anything, or spending on anything above the Basic/consumption tier.
- Do NOT git commit or push. I will decide.
- Only create the files named above. Do not add CI, Terraform/Bicep, Key Vault, Entra ID or extra features tonight.
- On any failed command: show the exact command and the exact error, then propose one fix. Do not retry the same command blindly.
- After each numbered step, print one line: DONE step N: what now exists.
</constraints>

<done_when>
The public URL serves the hello page, one embedding and one chat call returned 200, and azure_setup.md exists with no secrets in it. Then stop and print a five-line summary I can paste to my team.
</done_when>
```
This prompt is for an agentic tool with real system access. Review the scope locks, forbidden actions and stop conditions before pasting.

---

## Noah and Matthew: plan text checks

### Steps for Noah and Matthew
1. Pull the repo. Open your AI tool with access to the `Finalists/` folder.
2. Split the 34 PDFs by row order in [MANIFEST.csv](../data/raw/agency_plans/MANIFEST.csv): **Noah takes rows 1 to 17, Matthew takes rows 18 to 34** (data rows, not counting the header).
3. Paste the prompt below. Replace `[NAME]` with your name and `[ROWS]` with your row range.
4. Each of you writes your own file so you do not overwrite each other: `src/docs/plan_text_check_noah.csv` and `src/docs/plan_text_check_matthew.csv`.
5. Spot-check 3 of your rows by opening the PDF yourself. AI tools sometimes claim a goals section exists when it does not. Note any AI error you catch; it goes in the GenAI field notes.
6. When both files are done, Noah combines them into `src/docs/plan_text_check.csv` and you both agree the top-3 shortlist. Send the shortlist to Kent **before 7:30 pm**.

### Prompt for Noah and Matthew (any repo-aware AI)
```text
Role: you are a careful data analyst checking whether government PDF documents are usable as text input for a program. Accuracy matters more than speed. If you cannot verify something, write "unknown"; never guess.

Context: our team is building a tool that matches federal grant opportunities to North Carolina state agencies, using each agency's strategic plan as the agency profile. The plans are PDFs in Finalists/data/raw/agency_plans/. Finalists/data/raw/agency_plans/MANIFEST.csv lists them (columns: agency, url, http, content_type, bytes, file). I am [NAME] and I am responsible for data rows [ROWS] of MANIFEST.csv (row 1 is the first row after the header).

Task: for each PDF in my rows, extract its text with a local tool (for example pdftotext or pdfinfo from poppler, Python pypdf, or R pdftools; use whichever is already installed, and ask me before installing anything), then record:
- agency: from MANIFEST.csv
- file: from MANIFEST.csv
- pages: page count
- text_extractable: yes (normal text), partial (some pages empty or garbled), or no (scanned images, no text)
- chars_extracted: total characters of extracted text
- goals_section_found: yes or no; yes only if you found a heading or list of goals, objectives or priorities in the extracted text
- goals_page: page number where that section starts, or unknown
- goals_quote: the first goal, quoted exactly from the extracted text, under 25 words, or blank
- plan_years: years the plan covers, quoted from the text (for example 2025-2029), or unknown
- notes: anything odd (tables only, very long, not a single agency, duplicate)

Output: write a CSV with exactly those columns in that order to Finalists/src/docs/plan_text_check_[NAME].csv (lowercase name). Then print, in chat, a short ranked list of the 3 agencies in my rows that are best for a first end-to-end build: extractable text, a clear goals section, current plan years. One line of reason each, citing the goals_quote.

Rules:
- NEVER modify, move or rename anything in Finalists/data/raw/.
- Write only the one CSV file. Do not commit or push.
- Every goals_quote and plan_years value MUST be copied from the extracted text, not paraphrased or recalled.
- If a command fails, show me the exact command and error before trying something else.
Done when the CSV has one row per PDF in my range and the top-3 list is printed.
```
If your AI tool cannot run commands, tell Kent. The fallback is opening each PDF by hand and filling the same columns.

---

## Everett
Nothing assigned for now. First pickups if Kent hands them over: workshop notes, the data contract with Marco, or one Grants.gov API test call.

## Not tonight
UI, scoring, slides, bonus quests, evaluation labeling, and the diagram skills (installed in `.claude/skills/`, use after deploy).

## After the sprint, only if there is energy
One live Grants.gov pull into Blob. Sleep matters more.

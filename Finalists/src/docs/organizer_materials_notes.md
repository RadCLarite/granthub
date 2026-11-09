# Notes on the organizer materials

Read Fri Nov 6, 2026. Sources are in `data/raw/organizer/` (Starter Kit docx, Azure Access Guide docx, Presentation Template pptx, `additional-tools-1.zip` and its extracted folder). Plans are in `data/raw/agency_plans/`. Notes below separate what the files say from what I infer.

## 1. Starter Kit (`Solveathon-Starter-Kit.docx`)

What it is: an organizer-written playbook for this exact challenge. It gives a reference architecture, Azure CLI setup steps, a build spec per component, an evaluation recipe, a pitch time map and a de-scope ladder. It contains no application code.

### Its default recommendations
- **One agency only**, for example NC DEQ, or the agency whose sponsor we spoke with Friday. One real strategic plan "is enough to prove the method". More agencies only if time is left.
- **Data:** Grants.gov Search API, `POST https://api.grants.gov/v1/api/search2`, public, no key. SAM.gov is optional and needs a free key.
- **User screen:** ranked shortlist with score, plain-English reason, deadline, and Pursue / Maybe / Pass buttons.
- **Stack:** "Use any language." It names Python with Streamlit as the fastest path.
- **Azure design:** one container image with two roles, set by env var `MODE=app` (web UI) or `MODE=job` (daily refresh). All state is JSON files in one Blob container. Services: Resource Group, Blob Storage, Azure OpenAI (`text-embedding-3-small` plus a small chat model such as `gpt-4o-mini`), Container Registry (Basic), Container Apps environment, Container App (web), Container Apps Job (cron `0 10 * * *`, about 6 AM Eastern), Log Analytics. Key Vault, Entra ID and App Insights are "pitch only".
- **Cost claim:** about $30 to $80 per month at pilot scale [from the kit, unverified].
- **Fallback:** if Azure OpenAI is unavailable, scoring can fall back to keyword/TF-IDF.

### Data contract (agree before coding)
Blob container `ffm-data`: `profiles/{agency}.json`, `raw/{yyyy-mm-dd}/grants.json`, `opportunities/latest.json`, `scored/{agency}/latest.json`, `decisions/{agency}.json`, `eval/labels.json`, `runs/{timestamp}.json`.
Minimum opportunity schema: id, source, number, title, agency, status (posted/forecasted), open_date, close_date, days_to_close, eligibility, category, award_ceiling, description, url, ingested_at. Records missing key fields are flagged low-quality, not dropped.

### Suggested scoring blend (a starting point, not required)
Semantic similarity about 45%, keyword/program fit about 25%, eligibility about 15% (or a hard filter), timing about 10%, funder affinity about 5%. Output per item: score 0 to 100, breakdown, best-matching goal, High/Medium/Low confidence.

### Build components it lists
Agency profile builder (4 to 8 goals, 20 to 40 keywords, each goal cites a page; AI drafts, a person reviews), ingestion (200+ opportunities per run, also a broad no-keyword pull to measure what keyword-only monitoring misses), normalize and de-duplicate, scoring, AI summaries for the top N only (say "not stated" rather than guess), staff UI, daily refresh job (idempotent, non-zero exit on failure), feedback loop (bonus).

### Evaluation recipe
Label 20 to 30 opportunities (top, middle, random) by two teammates without seeing the score. Compute precision@10 and recall in the top 25 on the labeled set. Compare to a keyword-search baseline and report what we found that it missed. Record at least two failures (for example a false positive from a generic word like "water"). An evidence-slide table is provided.

### Pitch time map (6 minutes)
Understand 0:00 to 0:45, Frame 0:45 to 1:15, Solve with live demo 1:15 to 3:30, Evaluate 3:30 to 4:45, Drive Impact 4:45 to 6:00.
Pilot talking points: 60 days, 2 to 3 agencies, one coordinator each, coordinators keep manual checking so recall can be measured fairly. Scale: profile template per agency, Entra ID, Key Vault, Azure AI Search, email/Teams alerts, feedback-tuned weights.

### Deliverables checklist (kit version)
Working Azure prototype with a public URL that works on venue Wi-Fi and a phone hotspot; backup screen recording; 6-minute deck; Solution Design document (architecture, services, data contract, scoring, threats); GenAI Field Notes (tools, 3 to 5 key prompts, at least one AI error and how it was caught); repo with README (purpose, architecture, setup, env vars, how to run locally, how to run the job, how to add an agency, known limitations); no secrets in the repo.

### Minimum viable demo ("never cut")
One real agency profile from a real plan; real Grants.gov data (live or snapshot); ranked list with an explanation per item; a human decision button; one evaluation number and one honest failure.
De-scope ladder, cut first to last: second agency/SAM.gov/feedback-tuned weights, AI summaries, embeddings, the scheduled job, and last Azure deployment ("check the rules with a mentor first, because the prototype is expected to run on Azure").

### Pitfalls it names
Over 2 hours on infrastructure before any data or UI; calling the LLM for every item; a score with no explanation; demoing only from a laptop; hiding failures; committing keys.

## 2. Azure Access Guide (`Solveathon_Azure_Access_Guide-1.docx`)
- Portal: https://portal.azure.com. Sign in as `ONYEN@ad.unc.edu`, approve Duo, choose directory UNC-Chapel Hill.
- Search Subscriptions for `solveathon`. The team subscription is named `unc-sdis-solveathon-teamXX` (XX is the team number). Create all resources in it.
- If it does not appear: sign out, back in, search again. Then email Pratik Patekar (patekar@unc.edu), Haihan Gao (hhgao@unc.edu), Girish Wangikar (girishw@unc.edu), with name, team name, subscription name and a screenshot, CC all three.
- Not stated in the guide: which services or quotas the credits cover, whether Azure OpenAI is pre-provisioned. The kit says to skip its Step 3 if organizers provide Azure OpenAI.

## 3. Presentation Template (`Solve-a-thon-Presentation-Template.pptx`)
13 slides, footer "Solve-a-thon 2026", Carolina Blue theme. Order and prompts:
1. Title: presentation title, team name and member names, date.
2. Section: Solution Design.
3. Solution Design: the problem, how we defined end users, key user requirements.
4. Proposed Solution (section).
5. Design Architecture: how we designed the solution; can be folded into the demo.
6. Demo of Solution: the bulk of the time. Show evidence it works and where it is weaker. Pre-recording the demo and narrating live is recommended.
7. Architecture: very high level, key technical decisions.
8. Pilot and Scaling (section).
9. Plan for Pilot: how to pilot and scale.
10. Question and Answer.
11. Optional: team name and contact info.
12. End slide.
13. Additional content for Q&A backup. Template says: "you only have 6 minutes".
Template slides are layouts with prompts, so the AI-built deck should keep this order. The template has speaker notes on 4 slides (not read).

Implication: the template and the Starter Kit both say 6 minutes. That settles the 5 versus 6 question in favor of 6, with a brief demo. Still confirm if an organizer says otherwise.

## 4. `additional-tools-1.zip`
Contents (extracted into `data/raw/organizer/additional-tools/additional tools/`, read, nothing run, nothing installed):
- `README.md`, `Guide.docx`, `Recommended-Inputs.docx`: how to use two "skills" with Copilot in VS Code (copy to `.github/skills/`) or any chat AI.
- `skills/architecture-security-diagram/SKILL.md`: instructions for an AI to turn a deck, README, code and infra files into an architecture diagram (C4 style) and a security/threat-model diagram (STRIDE, OWASP Top 10 for LLM apps, Azure Well-Architected, Zero Trust, NIST CSF), output as SVG files plus a self-contained `report.html` and `assumptions.md`.
- `skills/stakeholder-map/SKILL.md`: same idea for a power/interest grid, stakeholder onion, and RACI.
- `examples/`: finished sample outputs for the Federal Funds Matchmaker (SVGs, `report.html`, `assumptions.md`), dated 2026-10-21. These are samples from the organizers, not our work.
Safety check: both SKILL.md files are plain-text instructions. I grepped for network, shell and install patterns and found only normal diagram terms. The two `report.html` files contain no `<script>` tags. No code in the zip.
How it could help: the architecture and security diagrams feed the template's "Design Architecture" and "Architecture" slides and the Solution Design document. The stakeholder map feeds the Understand and Drive Impact stages and the field notes. Cost: 20 to 40 minutes each per the guide, and the AI output must be checked against what we actually built (the guide says assumptions are where it is most likely wrong). Do this after the build exists, not before. Use is AI use, so log it in `AI_USAGE_LOG.md`.

## 5. Agency strategic plans (`data/raw/agency_plans/`)
Downloaded Nov 6, 2026 from https://www.osbm.nc.gov/operational-excellence/strategic-planning/agency-strategic-plans. Files are unmodified. `MANIFEST.csv` has agency, URL, HTTP status, bytes and file name for each.
- 34 files, 63 MB total, every one has a PDF header (checked), every HTTP status 200. Largest is the NC Community College System plan (24.6 MB), none over 50 MB.
- Includes three items that are not a single agency: State Board of Education Plan, Guiding Principles, Department of Public Schools (DPI). Also UNC System and NC Community College System.
- Not checked: page counts, whether text is extractable (versus scanned images), plan years. No PDF tool is installed here (`pdftotext`, `pypdf` absent). The DHHS file name says 2026-2030 and the OSBM file name says 2025-29; other years unknown [uncertain].
- Gap to plan for: the plans differ in length and structure. That is the "uneven agency documentation" threat the organizers named.

## 6. Where this conflicts with, or sharpens, what we had
- **One agency versus many.** The kit tells us to serve one agency and treat more as optional. Our docs left the agency count open. Recommended: one agency, plus a second only to show the template generalizes. The agency choice should come from the sponsor in the workshop. DEQ is only the kit's example.
- **Stack.** We decided Friday morning to keep R and Quarto. The kit and its time estimates assume Python with Streamlit, and the Azure OpenAI SDK and Container Apps flow are documented for Python. R can run in a container (for example Shiny, `plumber`) and call Azure OpenAI over HTTP, but we would build and debug more ourselves in the 5 to 7 hour window the kit assumes. This is a real tradeoff to decide tonight, not something I should decide for Kent. The existing R scoring engine is reusable either way via its criteria table, or by porting the logic.
- **Azure OpenAI replaces local Ollama.** Our LLM helper uses local Ollama. It does not satisfy "runs on Azure".
- **Ranking idea.** Our blind onboarding ranking is compatible with the kit's feedback bonus, which uses Pursue/Maybe/Pass on the shortlist. Ours adds a calibration step before the first list. It is not in the kit.
- **Lanes.** The kit proposes four lanes (Cloud and Ops, Data, Matching and AI, App and Story) which differ from the RUNBOOK roles (client, data and testing, story, Q&A). Decide tonight whether to adopt the kit lanes, since the Azure setup is a one-person lane that gates everything.
- **Timeline.** The kit assumes 5 to 7 hours on Saturday. Our code freeze is Saturday 7:00 to 8:00 pm, so we have more time, but the kit's milestone order is worth following: Azure and data in hour one, a deployed URL by mid-afternoon.
- **Evaluation.** The kit gives a ready recipe (precision@10, recall in top 25, two labelers, keyword baseline). Adopt it. Write the pass/fail targets before looking at results.
- **Qualifier assets.** The qualifier cached about 1,662 Grants.gov records. A cached snapshot is exactly the "demo fallback" the kit recommends. Check its date and fields before relying on it [uncertain].

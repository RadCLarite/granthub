---
name: architecture-security-diagram
description: Turn a team's project documents (pitch deck, README, source code, infrastructure-as-code, design notes) into an industry-standard solution ARCHITECTURE diagram and a SECURITY / threat-model diagram, delivered as a folder of SVG files plus a self-contained HTML report. Use when asked to "draw the architecture", "create a security diagram", "threat model my solution", or "document how my Azure solution works".
---

# Architecture + Security Diagram Skill

You are acting as a **cloud solution architect and security architect**. Your job is to read whatever
material a team provides and produce two professional diagrams and a report that look like the work
of an industry architecture review board.

The inputs differ between teams. Some teams provide a full repo, and others provide only a few slides.
Do **not** refuse or stall because information is missing. Extract what exists, infer sensibly, and
**label every inference as an assumption**.

---

## 1. Inputs to accept (any combination)

| Input type | What to look for |
|---|---|
| Pitch deck (PPTX/PDF/text export) | Problem, users, solution flow, screenshots, "how it works" slides |
| README / docs | Setup steps, services used, environment variables, architecture notes |
| Source code (any language) | Imports/SDKs (e.g. `azure-*`, `openai`, `requests`), endpoints, DB clients, auth code |
| Infrastructure-as-code | Bicep, ARM, Terraform, `azure.yaml`, Dockerfile, GitHub Actions workflows |
| Config files | `.env.example`, `appsettings.json`, `local.settings.json`, `requirements.txt`, `package.json` |
| Free-text answers | Answers to the questions in *Recommended Inputs* |

If the user gives **nothing usable**, ask at most 5 short questions (see §9), then proceed.

---

## 2. Process (follow in order)

### Step 1: Inventory
Build an internal **component inventory**. For each item record:
`id, name, type (person | external system | app/UI | API/function | AI service | data store | identity | monitoring | network), technology (e.g. "Azure Functions (Python)"), purpose, evidence (file/slide where found) or "ASSUMED"`.

Detection hints (generic):
- SDK/package names → services (`azure-storage-blob` → Blob Storage, `azure-search-documents` → AI Search, `openai`/`AzureOpenAI` → Azure OpenAI, `azure-cosmos` → Cosmos DB, `pyodbc`/`mssql` → Azure SQL, `azure-identity` → Entra ID/Managed Identity, `azure-keyvault` → Key Vault, `streamlit`/`flask`/`react` → UI tier).
- URLs → external systems (e.g. `api.grants.gov`, `api.sam.gov`, any public dataset/API).
- Env vars ending in `_KEY`, `_SECRET`, `_CONNECTION_STRING` → secrets (security finding if not in Key Vault).
- Workflows (`.github/workflows`) → CI/CD component.

### Step 2: Data flows
List each flow as `from → to : what data, protocol, sync/async, contains sensitive data? (Y/N)`.
Number them (1, 2, 3 …) in execution order. These numbers appear on the diagram.

### Step 3: Classify data
Use a simple scheme: **Public**, **Internal**, **Confidential**, **Restricted** (PII, credentials, keys).
State the classification for each data store and flow.

### Step 4: Threat model (STRIDE)
Draw **trust boundaries** wherever data crosses between zones of different trust:
- Internet / end-user device
- Public third-party APIs
- Your cloud subscription / resource group
- Private/VNet zone (if any)
- AI model boundary (prompt → model → output)

For each element that crosses a boundary, evaluate STRIDE:

| Letter | Threat | Typical cloud mitigation |
|---|---|---|
| **S** Spoofing | Pretending to be a user/service | Entra ID sign-in, Managed Identity, MFA |
| **T** Tampering | Modifying data/code | HTTPS/TLS 1.2+, signed deployments, RBAC, immutable storage |
| **R** Repudiation | Denying an action | Audit logging, App Insights / Log Analytics |
| **I** Information disclosure | Leaking data | Key Vault, private endpoints, encryption at rest, least privilege |
| **D** Denial of service | Making it unavailable | Rate limits, retries/back-off, quotas, autoscale |
| **E** Elevation of privilege | Gaining more rights | Least-privilege RBAC, no shared admin keys, input validation |

**Also include AI-specific risks** whenever an LLM is used, based on the OWASP Top 10 for LLM Applications:
prompt injection (from user input *or* ingested documents), sensitive-data leakage in prompts,
hallucination/false outputs (human-in-the-loop review), over-reliance, unbounded consumption (cost).
Map each one to a mitigation such as Azure AI Content Safety, grounding with citations, output validation,
a human approval step, or token/cost limits.

Rate each threat **High / Medium / Low** using likelihood × impact. Keep it to roughly the top 8–12 threats.

### Step 5: Map to frameworks (lightweight)
In the report, tag mitigations with relevant controls so students see industry vocabulary:
- **Azure Well-Architected Framework** pillars: Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency.
- **Zero Trust** principles: verify explicitly, use least privilege, assume breach.
- **NIST CSF 2.0** functions: Govern, Identify, Protect, Detect, Respond, Recover.
- (Optional) **Microsoft cloud security benchmark** control families (e.g. IM = Identity Mgmt, DP = Data Protection, LT = Logging & Threat detection).

### Step 6: Draw diagrams (see §4, §5, §6) → Step 7: Write report (see §7) → Step 8: Self-check (see §8).

---

## 3. Output folder (REQUIRED)

Create exactly this structure. Use `<team-slug>` = lowercase team/project name with hyphens.

```
<team-slug>-architecture-security/
├── architecture.svg          # C4-style container diagram (+ optional context strip)
├── security.svg              # Threat model / data-flow diagram with trust boundaries
├── report.html               # Self-contained report; embeds both SVGs inline
└── assumptions.md            # Every assumption + open question, for the team to confirm
```

If you cannot write files (for example in a plain chat window), output each file in its own fenced code block
headed with its filename. The user can then save them manually. **Never** abbreviate SVG/HTML with "…".

---

## 4. Architecture diagram standard (`architecture.svg`)

Follow the **C4 model, Level 2 (Container)** with a thin **Level 1 (Context)** framing:
- **People** (users/roles) at the **top**.
- **The system boundary** as a large dashed rounded rectangle labelled `[System] <Name>`.
- **Containers** inside the boundary (UI, API/Functions, AI services, data stores, and so on).
- **External systems** **outside** the boundary (left/right/bottom), styled grey.
- **Supporting/platform services** (identity, secrets, monitoring, CI/CD) in a separate band at the bottom of the boundary.
- **Arrows** labelled with a number + short verb phrase + protocol, e.g. `① Fetch opportunities (HTTPS/JSON)`.
  When space is tight, put only a **numbered badge** on the arrow and add a **Flow key** panel listing
  `n  From → To: what · protocol/auth`.

Every box shows 3 lines: **Name** (bold), `[Type: Technology]` (small), and a one-line purpose.

Layout guidance: flow left→right or top→bottom, avoid crossing lines, keep ≥ 24 px gaps, and use a grid.

## 5. Security diagram standard (`security.svg`)

A **Data-Flow Diagram (DFD) threat model**, in the style of Microsoft Threat Modeling Tool / OWASP Threat Dragon:
- **Trust boundaries** = red dashed rectangles, each labelled (e.g. `TB1: Internet`, `TB2: Azure subscription`).
- Elements use DFD shapes: **external entity** = rectangle, **process** = rounded rectangle/circle,
  **data store** = open-ended rectangle (two horizontal lines) or cylinder.
- Flows that **cross a trust boundary** are drawn thicker and carry a **threat badge**, a small circle
  with an ID like `T1`, `T2`, coloured by severity.
- A **control badge** (small shield/square, green) beside each component shows key controls,
  e.g. `🔒 MI` (Managed Identity), `KV` (Key Vault), `TLS`, `RBAC`, `LOG`. Prefer text labels over emoji for portability.
- A legend explaining boundaries, severity colours, and badges.

## 6. SVG technical rules (both diagrams)

1. Valid, standalone SVG 1.1: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 W H" role="img" aria-labelledby="t d">`.
2. Include `<title id="t">` and `<desc id="d">` for accessibility.
3. **No external resources**: no web fonts, no `<image href="http…">`, and no scripts. Use `font-family="Segoe UI, Arial, Helvetica, sans-serif"`.
4. Define arrowheads once in `<defs><marker>`.
5. Canvas around 1400×900 (scale as needed). Minimum font size 12 px; titles 22–28 px.
6. Include in the diagram: **title**, **subtitle** (team name • diagram type • date • version), and a **legend** box.
7. Escape `&`, `<`, `>` in text (`&amp;` etc.).
8. Keep text inside its box: allow about 7 px per character at 12 px, and wrap to a second line rather than overflow.
9. Before finishing, mentally render the diagram: no label crossed by an arrow, no overlapping boxes, and nothing outside the viewBox.
10. Colour palette (colour-blind safe; meaning must also come from labels/shapes, not just colour):

| Element | Fill | Stroke |
|---|---|---|
| Person | `#08427B` (white text) | `#052E56` |
| Container (your system) | `#1168BD` (white text) | `#0B4884` |
| AI / ML service | `#6B4FBB` (white text) | `#4A3684` |
| Data store | `#2E7D32` (white text) | `#1B5E20` |
| External system | `#8A8A8A` (white text) | `#6B6B6B` |
| Platform (identity/secrets/monitoring) | `#F2F2F2` (dark text) | `#9E9E9E` |
| Trust boundary | none | `#C62828` dashed `8 4` |
| Threat High / Med / Low | `#C62828` / `#EF6C00` / `#F9A825` | n/a |
| Control badge | `#2E7D32` | n/a |

## 7. HTML report standard (`report.html`)

One self-contained HTML5 file with inline CSS only and no JS or CDN. It must render offline and print cleanly to PDF.
Sections in this order:
1. **Header**: project name, team, date, version, "Generated with AI assistance; reviewed by: ____".
2. **Executive summary**: 3–5 sentences on what the system does and its security posture.
3. **Architecture diagram**: inline the full `architecture.svg` markup, followed by a caption.
   **Prefix every `id`, plus its `url(#…)` and `aria-labelledby` references, per figure** (e.g. `fig1-arw`, `fig2-arw`).
   Duplicate IDs across inlined SVGs break arrowheads.
4. **Component catalogue**: table with Component | Type | Technology | Purpose | Evidence/Assumed.
5. **Data flows**: table with # | From → To | Data | Protocol | Classification.
6. **Security diagram**: inline `security.svg`, followed by a caption.
7. **Threat register**: table with ID | STRIDE/LLM category | Element/Flow | Threat | Severity | Mitigation | Framework tags | Status (Implemented / Planned / Gap).
8. **Well-Architected quick check**: one row per pillar, with a status icon (✅/⚠️/❌) and a one-line note.
9. **Assumptions & open questions**: mirrors `assumptions.md`.
10. **Recommended next steps**: top 5, prioritized.
11. **Glossary**: C4, STRIDE, Trust boundary, Managed Identity, Zero Trust, and so on, kept short for student learners.

Style: max-width 1100 px, system font, tables with zebra rows, severity chips coloured as in the palette,
`@media print` rule to avoid splitting tables/diagrams across pages.

## 8. Quality self-check (do before finishing)

- [ ] Every component in the diagrams appears in the catalogue, and the reverse is also true.
- [ ] Every numbered arrow appears in the data-flow table.
- [ ] Every flow that crosses a trust boundary has at least one threat or a note explaining why none applies.
- [ ] If an LLM is used, at least prompt injection, hallucination, and data leakage are addressed.
- [ ] Every secret/credential found in code is flagged (do **not** reproduce actual secret values; mask them as `****`).
- [ ] Assumptions are explicitly labelled `ASSUMED` in tables and listed in `assumptions.md`.
- [ ] SVGs are well-formed XML and contain no external references.
- [ ] Text is readable at 100% zoom, and no labels overlap.

## 9. If information is missing, ask these (max 5, then proceed)

1. Who uses the solution, and how do they sign in (if at all)?
2. Which cloud services did you actually deploy (or plan to)?
3. What external data sources/APIs do you pull from?
4. Where is data stored, and does any of it contain personal or sensitive information?
5. Where do your API keys/secrets live today?

## 10. Reference example

If available, see `examples/federal-funds-matchmaker-architecture-security/` in this toolkit for a finished
sample output that shows the expected quality bar. Do **not** copy its content; derive everything from the team's inputs.

## 11. Tone and scope

- Audience: undergraduate teams, judges, and public-sector stakeholders. Be clear, use jargon only with definitions, and avoid vendor marketing.
- Distinguish **"as-built"** (evidence in code) from **"target/recommended"** (your suggestions). Use solid lines for as-built and dashed grey for recommended additions, and say so in the legend.
- Do not invent compliance claims (e.g. "FedRAMP compliant"). Say "consider/align with" instead.

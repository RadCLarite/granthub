---
name: stakeholder-map
description: Turn a team's project documents (pitch deck, problem statement, README, interview notes, challenge brief) into an industry-standard STAKEHOLDER MAP. It produces a power/interest grid, a stakeholder onion diagram, and a RACI/engagement plan, delivered as a folder of SVG files plus a self-contained HTML report. Use when asked to "map stakeholders", "who are our stakeholders", "create a stakeholder analysis", or "power interest grid".
---

# Stakeholder Map Skill

You are acting as a **business analyst / product manager** applying stakeholder-analysis practices used
in industry and government (PMI PMBOK stakeholder management, the Mendelow power/interest grid, Ian Alexander's
stakeholder onion model, and RACI).

Teams give different inputs. Work with whatever you receive, infer sensibly, and **label every
inference as an assumption**. Never stall because information is missing.

---

## 1. Inputs to accept (any combination)

| Input | What to extract |
|---|---|
| Challenge brief / problem statement | Sponsor/owner organisation, who is affected, constraints, success criteria |
| Pitch deck | Target users, personas, "who benefits", value proposition, impact slide |
| README / solution notes | User roles, admin roles, data providers, integrations (each integration owner is a stakeholder) |
| Interview / research notes | Quotes, pain points, attitudes (support/resist), influence |
| Free-text answers | Answers to the questions in *Recommended Inputs* |

---

## 2. Process

### Step 1: Identify stakeholders
Brainstorm broadly, then deduplicate. Consider these categories so that nobody is missed:

| Category | Prompts |
|---|---|
| **Users** | Who uses the solution day to day? Who uses its outputs? |
| **Sponsors / owners** | Who funds it, owns the problem, or approves go-live? |
| **Decision makers** | Who makes the final call on the outcomes the solution informs? |
| **Operators / IT** | Who will run, secure, support, and maintain it? |
| **Data providers** | Whose data/APIs does it rely on? |
| **Regulators / oversight** | Auditors, legal, privacy, compliance, policy bodies, legislators |
| **Beneficiaries** | Who ultimately benefits (citizens, communities, customers)? |
| **Negatively affected / resistors** | Whose workload, power, or status changes? Who might lose out? |
| **Partners / vendors** | Cloud provider, universities, NGOs, contractors |

Use **specific roles**, not vague groups (for example "Agency grant manager" rather than "government"). Aim for 10–20 stakeholders.

### Step 2: Profile each stakeholder
Record for each: `id, name/role, organisation, category, internal|external, power (1–5), interest (1–5),
attitude (Champion | Supporter | Neutral | Sceptic | Blocker), key needs, key concerns/risks,
what they need from the solution, what the team needs from them, evidence or "ASSUMED"`.

Scoring guide:
- **Power** 5 = can approve/stop/fund; 3 = can influence decision makers; 1 = little formal influence.
- **Interest** 5 = directly affected daily; 3 = affected periodically; 1 = rarely affected.

### Step 3: Place on the power/interest grid (Mendelow)
| Quadrant | Rule | Strategy |
|---|---|---|
| High power, High interest | P≥3, I≥3 | **Manage closely**: co-design, frequent updates |
| High power, Low interest | P≥3, I<3 | **Keep satisfied**: concise briefings, focus on their KPIs |
| Low power, High interest | P<3, I≥3 | **Keep informed**: demos, newsletters, feedback loops |
| Low power, Low interest | P<3, I<3 | **Monitor**: light-touch communication |

Draw the dividing lines at the **3.0** mark. Stakeholders scored exactly 3 count as *High* and are drawn just inside the upper/right half.

### Step 4: Onion layers (Alexander)
Place each stakeholder in a ring, working from the centre outwards:
1. **The Product / Solution** (centre)
2. **The System**: direct users and operators
3. **The Containing System**: sponsors, decision makers, functional beneficiaries, internal support
4. **The Wider Environment**: regulators, public, data providers, partners, negatively affected

### Step 5: RACI for key decisions/activities
Choose 4–8 key activities from the documents (for example "Define scoring criteria", "Approve
go/no-go on an opportunity", "Maintain data pipeline", "Security review", "Pilot rollout").
Assign **R**esponsible, **A**ccountable (exactly one per activity), **C**onsulted, and **I**nformed.

### Step 6: Engagement plan
For each High-power or High-interest stakeholder: objective, message, channel, frequency, owner.

### Step 7: Draw diagrams → Step 8: Write report → Step 9: Self-check.

---

## 3. Output folder (REQUIRED)

```
<team-slug>-stakeholder-map/
├── stakeholder-grid.svg      # Power/interest grid (primary deliverable)
├── stakeholder-onion.svg     # Onion diagram
├── report.html               # Self-contained report; embeds both SVGs inline
└── assumptions.md            # Assumptions + validation questions for the team
```

If you cannot write files (for example in a plain chat window), output each file in its own fenced code block headed by
its filename so the user can save it. **Never** abbreviate SVG/HTML with "…".

## 4. Power/interest grid standard (`stakeholder-grid.svg`)
- Canvas around 1400×1000. Plot area is a square with **Interest on the X-axis** (Low → High) and **Power on the Y-axis** (Low → High).
- Four quadrants with light tinted backgrounds and labels: *Keep Satisfied* (top-left), *Manage Closely*
  (top-right), *Monitor* (bottom-left), *Keep Informed* (bottom-right).
- Each stakeholder is a **circle marker** at (interest, power), with a short label. Avoid overlap by
  nudging markers slightly within their cell and using leader lines if needed.
- Marker **colour = attitude**: Champion `#1B7837`, Supporter `#7FBF7B`, Neutral `#BDBDBD`,
  Sceptic `#F1A340`, Blocker `#B2182B`. Marker **shape/outline = internal (solid) vs external (dashed outline)**.
- Optional: an arrow from current to **desired** position/attitude for key stakeholders (dashed).
- Include a title, subtitle (team • date • version), and legend (attitude colours, internal/external, arrows).

## 5. Onion diagram standard (`stakeholder-onion.svg`)
- 4 concentric circles/ellipses (centre = product), lightly tinted from dark to light outwards, each ring labelled.
- Stakeholder labels sit in "pill" shapes within the correct ring, distributed around it to avoid overlap.
- Use the same attitude colour coding on the pill border or fill as the grid, and include a legend.

## 6. SVG technical rules
1. Standalone SVG 1.1 with `xmlns`, a `viewBox`, `role="img"`, `<title>`, and `<desc>`.
2. No external fonts, images, or scripts. Use `font-family="Segoe UI, Arial, Helvetica, sans-serif"`, minimum 12 px.
3. Escape `&`, `<`, `>`. Meaning must not rely on colour alone, so always show text labels.
4. Put numbered IDs (S1, S2 …) inside markers/pills, and repeat the ID with the full name in a key panel, the register, and the onion.
5. Check for overlaps: no two labels or pills may touch, and each onion pill must sit fully inside its ring band.
   Size the rings to fit the pill widths (about 7 px per character at 12 px), and place pills near the top/bottom of each ring, where the band is horizontal.
6. When inlining both SVGs into report.html, prefix every `id`, plus its `url(#…)` and `aria-labelledby` references, per figure (`fig1-`, `fig2-`) to avoid duplicate IDs.

## 7. HTML report standard (`report.html`)
Self-contained HTML5 with inline CSS only and no JS or CDN, and it must print cleanly. Sections in this order:
1. **Header**: project, team, date, version, and "Generated with AI assistance; reviewed by: ____".
2. **Summary**: 3–5 sentences on who matters most and why.
3. **Power/interest grid**: inline SVG and caption.
4. **Stakeholder register**: table with ID | Stakeholder | Org | Category | Int/Ext | Power | Interest | Attitude | Needs | Concerns | Evidence/Assumed.
5. **Onion diagram**: inline SVG and caption.
6. **RACI matrix**: activities × stakeholders, with R/A/C/I cells colour-chipped.
7. **Engagement plan**: table with Stakeholder | Objective | Key message | Channel | Frequency | Owner.
8. **Risks & mitigations**: stakeholder-related risks (resistance, data access, adoption, equity).
9. **Assumptions & validation questions**: what the team should go and confirm, and with whom.
10. **Glossary**: power/interest grid, onion model, RACI, champion/blocker.

## 8. Quality self-check
- [ ] Every stakeholder appears in the register, the grid, **and** the onion.
- [ ] Exactly one **A** per RACI activity.
- [ ] At least one stakeholder exists from each of: users, sponsor/decision maker, operators/IT, data provider, oversight, beneficiaries.
- [ ] At least one potentially **negatively affected** or sceptical stakeholder is considered.
- [ ] Assumed scores are labelled `ASSUMED` and listed in `assumptions.md`.
- [ ] SVGs are well-formed, labels don't overlap, and the legend is present.
- [ ] Use roles rather than real individuals' names unless the team supplied them explicitly.

## 9. Reference example
If available, see `examples/federal-funds-matchmaker-stakeholder-map/` in this toolkit for a finished sample output.
Do **not** copy its content; derive everything from the team's inputs.

## 10. If information is missing, ask these (max 5, then proceed)
1. Who owns the problem and who sponsors the solution?
2. Who will use it day to day, and who acts on its outputs?
3. Whose data or systems does it depend on?
4. Who might resist or be negatively affected?
5. Who has to approve it before it goes live (IT, security, legal, leadership)?

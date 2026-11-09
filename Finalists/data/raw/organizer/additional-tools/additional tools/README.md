# Additional Tools: AI Diagram Skills for the Solveathon

This folder contains reusable AI "skills" that turn your team's **pitch deck, README, Azure code and notes**
into industry-standard diagrams. You get an **SVG + HTML report** output folder ready for your deck, repo and Solution Design.

## What's inside

```
additional tools/
├── README.md                     ← you are here
├── Guide.docx                    ← how to use the skills with Copilot, ChatGPT, Claude, Gemini, M365 Copilot
├── Recommended-Inputs.docx       ← checklist + fill-in template for the best results
├── skills/
│   ├── architecture-security-diagram/SKILL.md   ← Architecture (C4) + Security (STRIDE threat model)
│   └── stakeholder-map/SKILL.md                 ← Power/interest grid + onion + RACI
└── examples/                     ← finished sample outputs (Federal Funds Matchmaker)
    ├── federal-funds-matchmaker-architecture-security/
    │   ├── architecture.svg  ├── security.svg  ├── report.html  └── assumptions.md
    └── federal-funds-matchmaker-stakeholder-map/
        ├── stakeholder-grid.svg  ├── stakeholder-onion.svg  ├── report.html  └── assumptions.md
```

## 60-second quick start

1. Read **Recommended-Inputs.docx** and gather your deck (as PDF), README, and key code files. **Remove all secrets.**
2. **If you use GitHub Copilot in VS Code:** copy `skills/*` into your repo at `.github/skills/`, open Copilot Chat in **Agent** mode, and ask:
   > Use the architecture-security-diagram skill on this repo. Team: "…". Save output in /diagrams.
3. **If you use any other chat AI:** upload `SKILL.md` + your files, and ask it to follow the skill and output every file as a full code block.
4. Open `report.html` in a browser, check `assumptions.md`, correct anything wrong, and regenerate.
5. Insert the `.svg` files into PowerPoint (Insert → Pictures) and commit the folder to your repo.

## Industry standards you'll practise

| Skill | Standards |
|---|---|
| Architecture + Security | C4 model · Data-flow diagram threat modeling · STRIDE · OWASP Top 10 for LLM Apps · Azure Well-Architected Framework · Zero Trust · NIST CSF 2.0 |
| Stakeholder Map | Mendelow power/interest grid · Onion model · RACI · Stakeholder engagement planning (PMI) |

> AI output is a **draft**. Your team is accountable for verifying it, and should disclose AI use in the GenAI Field Notes.

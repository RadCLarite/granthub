# "For researchers" tab: design (decided 2026-11-09)

Source: a question-by-question session with the owner. The same decisions are logged in the owner's ClaudeSpace `granthub/decisions.md`.

## Purpose
A screening aid for medical researchers, mainly PIs. A PI describes their work and sees open federal opportunities ranked by fit, each with mechanism, budget, deadline, trial status and a warning when there is not enough time to apply. It never predicts the chance of winning and never drafts application text.

## Scope
- New tab "For researchers" in `tool/matchmaker.html`, beside the existing NC agency tabs. The agency tool is unchanged.
- Funders: federal now; foundations in phase 2 (broad biomedical list, each row with source URL and verified-on date).
- Inputs: pasted abstract, keywords. ORCID iD and a pasted publication list in phase 2. A Google Scholar link is not supported (no API, the browser cannot fetch it).
- Matching: local BM25 with a biomedical synonym list; matched terms shown. No embeddings.
- Fields per card: fit and matched terms, mechanism, eligibility, trial status, budget, deadline, human-subjects flag. Rules only. Anything not resolved shows "unknown", never a guess.
- Optional filters: career stage, institution type, plans a clinical trial, budget range, preferred mechanisms, human subjects or animals, small business.
- Time warning: per-mechanism lead times (R01 8 weeks, R21 6, K 8, editable, labelled as estimates) plus a sign-off lead time of 5 business days (editable).
- First screen: one search-first page with 3 example searches in the owner's field.

## Phases
1. Pool, parsing, BM25 matching, filters, time warnings, the tab, a 20-award test set.
2. ORCID and OpenAlex, foundation list, calendar and RSS feeds, unusual-case checklist (trial, foreign, multi-PI, subaward, cost share, IND/IDE, data sharing, animals or human subjects, letter of intent).
3. Human validation: about 5 PIs rate the top 10 for their own abstracts; bar 6 of 10 "worth a look".

## Test set
20 funded awards, 10 sampled by Claude from NIH RePORTER and 10 supplied by the owner. For each abstract the harness reports whether the award's own funder and mechanism appear in the top 10 results. The pass bar is set after the first run, not before.

## Out of scope
Drafting aims or application text, email alerts, accounts, embeddings, study-section info, win odds, multi-cycle NIH standard dates (not in the structured data).

## Trust rules carried over
No personal data stored or sent in phase 1 (phase 2 adds ORCID and OpenAlex reads behind a visible notice). Screening-aid and confirm-on-Grants.gov wording on every screen with a date or score. No key or secret in any tracked file.

# Pilot plan: what OSBM would be funding

Rubric target: Drive Impact, level 4 (the room wants to fund it; roadmap and risks are realistic, not aspirational) and Understand, level 4 (people who fund, approve and maintain it). Owner and cost are left blank on purpose: we do not have them from a sponsor and will not invent them. Role fits below are inferred from job titles, not from anything these people said.

## Who it touches
| Role | Who it would be (by title, our proposal) | What they need from it |
|---|---|---|
| Uses it | A grants lead at an agency; at agencies with no grants role, whoever scans for funding | A short ranked list with deadline, who must sign, and why it matched; no setup |
| Funds it | OSBM leadership, for example the OSBM Chief Scientist's office | A measured result from a small pilot before any larger commitment |
| Approves it | Agency leadership for cost-share items (26 Top 10 rows need leadership); state IT and AI project staff for data and AI use | Public data only, an AI that labels text but never decides, and a record of how each result was reached |
| Maintains it | A cross-agency team, as the sponsors described: no dedicated OSBM team exists | Plain tables to edit (`data/manual/`), one place for each rule, tests that fail loudly, a README they can follow |

Titles only: the repo is public, so we do not name the state staff and mentors who spoke or attended without their consent.

## The pilot
- Length and scope: 60 days, 2 to 3 agencies, keep each agency's manual checking running in parallel so we can measure what the tool catches that they do not (the starter kit's shape).
- Owner: left for OSBM to name. A pilot cannot start without one.
- What it replaces: the periodic survey and the one person who scans Grants.gov when they have time. It does not replace a grant writer.
- Cost: to be read from the Azure bill for month to date. The starter kit's $30 to $80 per month is unverified, so we do not quote it. Spend alerts exist at $50, $100, $250 and $400.

## How we would know it worked
- Pilot measure, already in the product: the share of Top 10 rows that staff mark Pursue or Maybe, from `/feedback` via `app/pilot_scorecard.sh`.
- Coverage: how many opportunities the agency would otherwise have missed, counted against the manual list kept in parallel.
- A "Yes" commits OSBM to: naming an owner, giving 2 to 3 agencies a grants contact for 60 days, and reading the measure at the end.

## Roadmap
| Step | State today |
|---|---|
| Rank and show Top 10 per agency, 32 agencies | Done, live on Azure |
| Feedback marks logged for the pilot measure | Done, marks do not yet change the ranking |
| Daily job that re-scores | Deployed as a dry run on a baked payload. Next: build the job image and give it permission to write |
| Fetch new postings automatically | Not built. Fetch is a manual, approved step. Next: run it as a scheduled job with keys held as secrets |
| Marks improve the ranking | Not built; test in the pilot |
| More agencies need a capability table | Only DHHS and DMVA have one |

## Risks, as they are
- Keyword matching misses differently worded grants; the pilot's parallel manual list is how we find out how many.
- Our evidence is a backtest on past awards, which favors repeat funding, and no agency staff have tested it.
- Plans are old at four agencies; the tool is only as current as the plan text.
- The model behind the notice reader (`gpt-4o-mini`) is scheduled for retirement on 2027-04-14 [per Azure's listing at deploy time]; swapping it is a config change but a pilot should plan for it.
- Data refresh is manual until the job is finished.

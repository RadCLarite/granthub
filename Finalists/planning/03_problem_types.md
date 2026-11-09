# Problem types: which approach fits

Deloitte warned about anchoring on a method (or past data) before understanding the problem. The ranking skeleton fits one kind of problem. Decide which kind we have, then reuse only what applies.

**Rule:** use `rank_items()` only if the user's decision is a choice among a list of items. Otherwise reuse the plumbing (`read_any`, cache, tests, report, figure helpers) and write a new core.

| If the user needs to... | Type | Minimum viable method | Skeleton parts that apply | Test idea | Typical failure |
|---|---|---|---|---|---|
| Choose or prioritize among items (grants, sites, projects) | Rank | Filter, score, rank, explain | Everything | Boundary cases, ties, a known best and worst item | Criteria that are proxies for what the user means |
| Find where help is needed (counties, tracts, districts) | Place / gap | Rank geographic units on a need index; map the result | Skeleton with places as items; `nc_boundaries()`; map figure | Known high-need and low-need places | Population effects; ecological fallacy; stale boundaries |
| Estimate or forecast a quantity | Estimate | Simple baseline first (last year, average, trend), then one model | Loaders, cache, tests, report | Backtest on held-out period vs the baseline | Beating nothing; leaking the future; overfit |
| Flag or sort records into categories | Classify | Rules first; LLM labels with quotes for text; hand-label a sample | `helpers_llm.R`, tests | Hand-labeled sample accuracy, and where it is weakest | Labels with no evidence; class imbalance |
| Judge whether something worked | Evaluate | Compare to a defensible baseline; state confounders | Loaders, tests, report; use `statistical-analysis` for tests | Placebo or pre-trend check | Selection bias; causal claims from correlation |
| Understand or communicate a situation | Describe | A few clear charts and one number that matters; maybe the tool | `helpers_report.R`, tool (adapt) | Reader test: can a non-technical person state the takeaway? | Many charts, no point |

## Our likely type (Final Quest, [assumed] until the gate is ticked)
Rank (opportunities per agency profile) plus Classify (LLM labels agency goals and opportunity themes with quoted evidence, never the final decision). Reuse: `rank_items()`, `score.R`, `helpers_llm.R`, cache, tests, report, figures. Likely new: agency-profile builder from strategic plans, Azure deployment, a feedback loop if time allows. The model-side LLM must run in the Azure environment; local Ollama alone will not satisfy "runs on Azure". Record the final choice in `handoff.md`.

## Questions to ask for each type
- **Rank:** What is a good item? What disqualifies an item? How many can the user act on?
- **Place / gap:** What is a unit? What counts as need? Who decides where resources go?
- **Estimate:** What decision changes with the number? What error is tolerable?
- **Classify:** What is the cost of a false positive versus a false negative? Who reviews flagged items?
- **Evaluate:** What is the comparison? What else changed at the same time?
- **Describe:** Who sees this and what do they do next?

## What to check on Friday night
- Is there more than one type in the problem? Pick the smallest slice that triggers an action.
- If the problem is not a ranking one, write down in `handoff.md` which skeleton parts we keep and why.

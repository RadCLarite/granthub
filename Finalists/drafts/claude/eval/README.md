# Evaluation kit (draft, for Kent to approve)

Purpose: test with human judgment whether the ranked list finds what a grant writer would want, and compare it with a plain keyword search. People label. AI does not. This follows decisions 3, 8, 9, 11, 12 and 15 in `planning/08_product_decisions.md`.

## What is here
- `pool_rules.md`: how the 20-item pools were drawn (seed, date, method) and how that draw biases results. Read it first.
- `make_label_sheets.R`: draws the pool and writes blind sheets. It does not use the ranker.
- `keyword_baseline.R`: the simple comparison method (a keyword search). NOT our ranker; generic words give it false positives.
- `score_labels.R`: computes the numbers. `test_metrics.R`: checks the math on fake data, prints "N of N tests pass".
- `known_cases_draft.csv`: proposed must-pass and must-fail cases. Kent approves.
- `sheets/`: 3 agencies x 2 labelers (20 rows each), plus a hidden key. Labelers never open the key.

## Who does what
- **Everett** (data and testing) runs the labeling session, collects the filled sheets, and runs the scorer. He also owns the known cases.
- **Two labelers per agency** (A and B), working alone. Noah and Matthew can be the second pair if Everett and one other label the first.
- **Kent** sets N and the open settings below, approves the known cases, and says which result counts.
- **Kent/Claude pipeline** produces the ranking file (columns `agency, opp_id, rank`, optional `score`) for the FULL ranked list of each agency.

## Steps
1. Sat morning, now: sheets already exist (drawn from a fixed seed, before any ranking). Do not regenerate them after the ranker lands; that would change the pool after seeing it.
2. Each labeler fills the `label` column with exactly: `relevant`, `maybe` or `not relevant`. About 20 items, estimate 20 to 40 minutes each (not measured; time the first three items). "Relevant" = this agency's grant writer would want to look at it. "Maybe" = unclear from the notice. Rows marked "notice" have no deadline or award by design.
3. Save the filled sheets back into `sheets/` under the same names.
4. When the ranking exists, Kent sets `N_SHORTLIST` at the top of `score_labels.R`, then run `Rscript score_labels.R ranking=ranking.csv`. Results go to `results/`.
5. After the first scoring, each pair discusses the items they disagreed on (`labeler_disagreements_to_discuss.csv`). Save any change as a new file; keep the originals.

## Rules
- Label independently. Do not compare notes or look at the app, any score or rank, or the key file before you finish.
- AI must not fill, suggest or check any label.
- Call the result "team-labelled". It is never ground truth.

## How the score works
- **Primary: recall in the top N** with a 70% pass bar (decision 12; set in `score_labels.R`). Recall = of the pool items counted as hits, the share the ranker puts in its top N.
- **N is the shortlist cap on the agency's FULL ranked list (decision 3, `src/R/00_config.R`), not the pool size.** If someone ranks only the 20 pool items and uses N = 20, recall is automatically 100% and means nothing. The scorer refuses a ranked list shorter than 5 times the pool, refuses an unset N, and warns when N is at least the pool size. There is a test for this. **Kent must set N.**
- **Two readings, both shown:** "relevant only" and "relevant plus maybe". **Kent must say which one counts.** Also both rules for combining two labelers: strict (both say it) and lenient (either says it). Kent must say which one counts.
- **Secondary:** precision@10 (labeled items only) and the ranker versus baseline comparison, including items one method found and the other missed.
- **Threshold helper (decision 3):** `threshold_for_recall` gives the score at which the flag keeps 70% of the pool hits inside the top N. Needs a `score` column in the ranking file. "Lowest score that keeps 70%" is read as the score of the lowest hit you must keep to reach 70%; Kent to confirm.
- Recall by shortlist length (N = 10, 25, 50, 100, 200) is written to `recall_by_N.csv` for the named weakness (decision 11).

## What the numbers cannot prove
- 20 items per agency is tiny: one item moves recall by 5 to 10 points. Indicative only.
- Recall is only against the pool, not against all real opportunities. Keyword-picked items favor what keywords find, so recall can be overstated; the 8 random items are the guard.
- Agreement between two people shows consistency, not correctness.
- They do not show the tool saves time or wins grants.
- DHHS goals come from heading-only plan text with short descriptions, and partly OCR; check them before trusting DHHS results.

## Open for Kent
N; which reading and which combining rule count; the 70% bar if you want it changed; whether closed items belong in the pool (decision 1 scores them, the pool excludes them); how to treat past dates on forecasted items and award = 0; higher-education-only as "clearly ineligible"; whether DERA satisfies the Clean School Bus gate.

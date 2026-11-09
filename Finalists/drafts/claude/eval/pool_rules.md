# Pool rules (decision 12). Drawn and written down before any scoring.

- **Date drawn:** 2026-11-06 (the REF_DATE in `src/R/00_config.R`). Base seed: 2026 (the random draw for agency 1, 2, 3 uses 2027, 2028, 2029; shuffles use 2126 and up; see `make_label_sheets.R`). Rerunning the script gives the same pool.
- **Agencies (exact labels):** Department of Public Schools, Department of Environmental Quality, Department of Health and Human Services.
- **Size:** 20 items per agency. Two labelers (A and B) label every item independently. One label per item: relevant, maybe, or not relevant.
- **Where items come from:** the 1,576 rows with status posted, forecasted or notice (open items plus Federal Register notices, decision 9). Closed items are NOT in the pool. Decision 1 says the product scores closed items too, so this is a gap Kent may want to close.
- **Method, per agency:** (1) score every pool row with the keyword baseline (`keyword_baseline.R`, built from the agency's goal text). (2) Take the 6 highest-scoring hits. (3) Take 6 evenly spaced hits from the middle third of the remaining hits. (4) Draw 8 at random from everything else, zero-hit rows included. (5) Shuffle. The ranker is not used at all, so the pool cannot be tuned to it.
- **Display:** deadlines later than 2029-12-31 read "rolling or no date listed" (decision 8); notices read "no deadline (notice)" and "none (notice)" for award (decision 9); a missing award reads "unknown", never 0.

## How this draw biases the results (read before quoting any number)
- Most of the pool (12 of 20) was picked because keywords found it. Keyword-picked items are the ones a keyword method, and probably our ranker's text matching, finds best. Recall measured on this pool can therefore be **overstated**: relevant items that neither method finds mostly are not in the pool at all.
- The 8 random items are the only guard against this, so they stay. Expect few of them to be relevant; if a random item is relevant, that is the most valuable finding in the pool.
- The ranker versus baseline comparison favors the baseline's own picks in the baseline strata, and is fairer in the random stratum. Report it by stratum if the counts allow.
- With 20 items, one item moves recall by about 5 to 10 points. Numbers are indicative, and labels are "team-labelled", not ground truth.

# Researcher tab: test-set results

## First run, no pass bar set

Date: 2026-11-09. Pool: 1,225 open opportunities (`data/processed/research.json`, built 2026-11-09, listings fetched 2026-11-06). Awards: 10 NIH RePORTER awards (2 each: stroke imaging, radiology AI, MRI physics, oncology imaging, general biomedicine; fiscal years 2024 and 2025). `owner_abstracts.json` is still empty, so this is 10 of the planned 20. Command: `node tests/research/run_testset.js`.

```
10 awards run against a pool of 1225 opportunities (search limit 50)
IC hit@10: 5 of 9 testable in top 10 (55.6%), 1 not testable
Mechanism hit@10: 7 of 10 testable in top 10 (70.0%), 0 not testable
IC and mechanism each in top 10 (separate rows): 4 of 9 testable in top 10 (44.4%), 1 not testable
Pool share with known IC (funder_known): 13.4%; known mechanism (mech_known): 39.7%
Random baseline (mean 1-(1-p)^10): IC 7.3%, mechanism 21.2%
```

"IC and mechanism each in top 10 (separate rows)" means the first same-IC result and the first same-mechanism result are each in the top 10; they need not be the same row (CSV column `hit_ic_and_mech`). An award is "not testable" for a metric when the pool has no row with that IC (or mechanism); it is removed from that denominator and counted separately. The query is the award title plus abstract.

### What this measures (a proxy)

This matches an abstract to CURRENTLY OPEN opportunities of the same funder and mechanism. It is not a check that a specific funded grant would have been found by the tool; the award was funded under an opportunity that is probably closed. A hit means the search points a researcher at the right funder or award type, nothing more.

### Reading the numbers

- IC is only known for 13.4% of pool rows (the code comes from RFA-XX numbers; most PAR/PA rows have none). The IC metric therefore rests on few rows (EB 1, AA 2, CA 11, NS 18 in the pool), and "not found" often means the pool has few or no rows for that IC, not that ranking failed. GM has zero rows, so the GM award is not testable for IC.
- Mechanism is known for 39.8% of rows, so the mechanism metric is the more meaningful one, but R01 alone is 79 rows, so R01 awards are easy to hit.
- Both metrics beat the random baseline (55.6% vs 7.3% for IC, 70.0% vs 21.2% for mechanism; the baseline is approximate and assumes 10 independent draws), but with 9 to 10 awards one award moves a rate by 10 points. No conclusion about quality should be drawn until the owner adds abstracts.

Three worst-ranked awards (ranks within the top 50 results; none means no same-IC or same-mechanism row appeared):
1. `reporter_5P41EB024495-07` (EB, P41, radiology AI): no EB row in the top 50 (pool has 1 EB row); P41 found at rank 3.
2. `reporter_1R01EB037669-01` (EB, R01, radiology AI): same EB problem; R01 found at rank 6.
3. `reporter_5F31CA288055-02` (CA, F31, MRI physics): first CA row at rank 28; the pool has 1 F31 row and it was not in the top 50. (`reporter_2P20GM103447-25`, GM/P20: IC not testable (no GM rows in the pool); P20 not in the top 50.)

## Synonym groups on versus off

Same harness, `--no-synonyms` flag (empty groups array) against the current 47 groups in `tool/research/synonyms.json`:

| Setting | IC hit@10 | Mechanism hit@10 | IC and mechanism each in top 10 (separate rows) |
|---|---|---|---|
| Groups off | 5 of 9 | 7 of 10 | 4 of 9 |
| Groups on | 5 of 9 | 7 of 10 | 4 of 9 |

Identical. The long abstract queries already contain the specific terms, and the groups changed the top-50 order for only 1 of 10 awards, with no change in any rank used by these metrics. On this test set the synonyms neither help nor hurt; they are likely to matter more for short typed queries, which this harness does not test.

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
- Mechanism is known for 39.7% of rows, so the mechanism metric is the more meaningful one, but R01 alone is 79 rows, so R01 awards are easy to hit.
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

## Phrase boost run (adjacent-word boost)

Date: 2026-11-09. Pool: 1,225 open opportunities. Awards: **10** NIH RePORTER awards (the 10 owner abstracts are not in yet, so this is not a 20-award result). Flag: `--phrase-boost=<n>`; 0 is the no-boost baseline, 0.5 is the shipped default (fixed before the run, not tuned). The harness queries with full abstracts (2,400 to 3,300 characters), so quoted phrases never apply here; the quoted-phrase filter is covered by unit tests only.

| Boost | IC hit@10 | Mechanism hit@10 | IC and mechanism each in top 10 (separate rows) |
|---|---|---|---|
| 0 (baseline) | 5 of 9 | 7 of 10 | 4 of 9 |
| 0.25 (sensitivity) | 5 of 9 | 7 of 10 | 4 of 9 |
| 0.5 (default) | 5 of 9 | 7 of 10 | 4 of 9 |
| 1 (sensitivity) | 5 of 9 | 7 of 10 | 4 of 9 |

Ship rule (set before the run): keep 0.5 only if no hit count falls below the baseline. None fell, so 0.5 stays the default. This shows no regression, nothing more: one award is 10 points, and these metrics count same-funder and same-mechanism rows, not topical fit.

What the boost did change, baseline to 0.5 (rank of the first same-funder row, then the first same-mechanism row; "null" means none in the top 50 or not testable):

| Award | IC rank | Mechanism rank | Top-10 rows that changed order |
|---|---|---|---|
| 5R01NS126509-03 | 2 to 1 | 1 to 2 | 8 |
| 2T32AA007577-26 | 5 to 3 | 3 to 4 | 3 |
| 5F31CA288055-02 | 28 | null | 1 (one new row entered the top 10) |
| 2P20GM103447-25 | null | null | 4 |
| other 6 awards | no change | no change | 0 |

So on real abstracts the boost reorders a few top-10 lists and moves the metric ranks by one or two places. It does not move any award across the top-10 line. Whether the reordered lists read better to a researcher is a question for the human check (phase 3), not this proxy.

## Phase 2 rerun (2026-11-10)

Phase 2 did not change ranking. Rerunning `node tests/research/run_testset.js` gives the same counts as before: IC hit@10 5 of 9, mechanism 7 of 10, both 4 of 9 (10 of the 20 awards have abstracts).

## Pool refresh rerun (2026-11-10)

Date: 2026-11-10. Pool: 1,426 open opportunities (`data/processed/research.json`, built and listings fetched 2026-11-10, summaries cut at 1,000 characters to fit the size budget). The pool was refreshed from Simpler.Grants.gov (206 rows added, 1 removed; 195 of the added rows are forecasted). Same 10 NIH RePORTER awards, same ranking code, same default phrase boost (0.5) and synonym groups.

```
10 awards run against a pool of 1426 opportunities (search limit 50)
IC hit@10: 4 of 9 testable in top 10 (44.4%), 1 not testable
Mechanism hit@10: 7 of 10 testable in top 10 (70.0%), 0 not testable
IC and mechanism each in top 10 (separate rows): 4 of 9 testable in top 10 (44.4%), 1 not testable
Pool share with known IC (funder_known): 15.7%; known mechanism (mech_known): 37.6%
Random baseline (mean 1-(1-p)^10): IC 9.1%, mechanism 19.8%
```

The IC hit rate is one award lower than the earlier runs (5 of 9, 55.6%); mechanism and the combined count are unchanged. The ranking code did not change: the difference comes from the new pool. Against the 2026-11-09 pool, three awards changed their IC result:

| Award | First same-IC rank, before to after | Top 10 |
|---|---|---|
| `reporter_1R01NS140757-01A1` (NS) | 27 to 5 | enters |
| `reporter_1F31CA305956-01` (CA) | 4 to 33 | leaves |
| `reporter_2T32AA007577-26` (AA) | 3 to 19 | leaves |

The other IC and mechanism ranks moved by one to a few places and crossed no top-10 line. Net: one award in, two out. With 9 testable awards one award is 11 points, so this is within the noise of a ten-award test set and is not evidence that the tool got worse or better. I did not test why the two awards fell; the likely cause is the 124 added NIH rows (mostly forecasted) competing for the top 10, but that is not checked. The random baseline moved too (IC 7.3% to 9.1%, mechanism 21.2% to 19.8%) because the shares of rows with a known IC and mechanism changed.

## Posted versus forecasted (2026-11-10)

`node tests/research/run_testset.js` now prints the test set three times, each against its own pool, so posted (active) and forecasted opportunities can be reviewed apart. Same 10 awards, same pool file as the refresh rerun above.

| Pool | Rows | IC hit@10 | Mechanism hit@10 | IC and mechanism each in top 10 | Known IC | Known mechanism |
|---|---|---|---|---|---|---|
| All | 1,426 | 4 of 9 | 7 of 10 | 4 of 9 | 15.7% | 37.6% |
| Posted (active) | 854 | 2 of 9 | 6 of 10 | 2 of 9 | 10.3% | 44.1% |
| Forecasted | 572 | 4 of 9 | 3 of 7 (3 not testable) | 1 of 6 (4 not testable) | 23.8% | 27.8% |

Each group is its own pool, so its testable awards and random baseline differ (posted: IC 5.6%, mechanism 25.3%; forecasted: IC 13.9%, mechanism 11.6%). The forecasted pool has no rows for some mechanisms, so three awards are not testable there; do not compare its hit counts with the posted ones directly. One award is 11 to 17 points in these small pools. Per-award files: `outs/research_testset_report_posted.csv` and `_forecasted.csv`.

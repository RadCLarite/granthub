# Research test set

`reporter_sample.json` is built by `R/15_build_research_testset.R` (public NIH RePORTER data). `owner_abstracts.json` is for you: add up to 10 abstracts of your own funded grants, then run `node tests/research/run_testset.js`.

Each element needs these fields (same as the RePORTER sample, with `source` set to `"owner"`):

```json
{
  "id": "owner_1",
  "source": "owner",
  "project_num": "5R01XX000000-01",
  "ic": "NS",
  "mechanism": "R01",
  "title": "Project title",
  "abstract": "Full abstract text.",
  "topic": "stroke imaging"
}
```

`ic` is the two-letter NIH institute code (see `data/manual/nih_ic_codes.csv`); `mechanism` is the activity code (R01, R21, ...). Awards with an empty abstract are skipped. Keep patient data out of abstracts.

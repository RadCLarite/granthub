# Data preparation

## Do not download before the gate
Deloitte rule: user and criteria on paper first. The exception is baseline NC data that is already cached (below).

## Already cached from the qualifier (verified by listing the folder)
In `QualifierChallenge/data/cache/`. Copy what is needed into `Finalists/data/cache/api/`; do not re-download.
- `api/acs_2023_nc_state.rds`, `acs_2023_nc_county.rds`, `acs_2023_nc_congressional_district.rds`: American Community Survey 2023 tables (which variables is in the qualifier's `01_load_clean.R`; check before use).
- `api/fema_declarations_nc.rds`: FEMA declarations for NC.
- `api/hrsa_mh.rds`, `api/hrsa_pc.rds`: names suggest HRSA mental health and primary care data [uncertain; check contents].
- `boundaries/nc_county_2023.rds`, `nc_tract_2023.rds`, `nc_place_2023.rds`, `nc_congressional_district_2023.rds`: boundary files. `nc_boundaries()` in `helpers_io.R` expects the same file names in `data/cache/api/` [untested that the objects are compatible].
- `llm/`: 24 MB of cached LLM labels from the qualifier. Only useful if the finals problem reuses the same texts.

## Candidate public sources to check (names only; I have not verified current URLs, formats, or terms)
- Census (ACS via `tidycensus`, needs a free API key), Census geography via `tigris`.
- NC state data portals and agency pages: NC OneMap, NC OSBM, NC DHHS, NC DEQ, NC DOT, NC Department of Commerce [uncertain which publish what].
- Federal: Grants.gov, CDC PLACES, HRSA, FEMA, BLS, HUD, USDA [uncertain which fit].
Verify each: current download link, license, file format, update date.

## Data intake checklist (one row per dataset; keep in `data/raw/README.md`)

| Field | Answer |
|---|---|
| Name and source URL | |
| Who gave it to us (organizers, public, client) | |
| License or terms | |
| Format and size | |
| Date range and last update | |
| Geography and the key that joins it (FIPS, ZIP, name) | |
| Unit of observation (what is one row) | |
| ID column and is it unique | |
| Missing values (profile output) | |
| Known issues from the data owner | |
| Contains personal or confidential data? (if yes: stop and tell Kent) | |
| Cached where, and the script that fetched it | |

## Handling
- `data/raw/` is never edited. Cleaning goes in a script and writes to `data/processed/items.csv`.
- Profile every file with `Rscript R/01_profile.R` before choosing a criterion field.
- Every external call goes through `cached_fetch()` or `fetch_paged()` so reruns are free and identical.
- Join on codes, not names. Check the join: row counts before and after, and unmatched keys.

## Fields every criterion needs
For each criterion in the framing worksheet, confirm: the field exists, it has few missing values, its units are what we think, and its meaning matches the client's word. Write what you found in the `why` column of `criteria.csv`.

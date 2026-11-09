# data/raw intake log

Never modify files here. Contains no participant or patient data.

| Folder or file | What | Source | Date added | Notes |
|---|---|---|---|---|
| `organizer/Solveathon-Starter-Kit.docx` | Organizer Starter Kit for the Federal Funds Matchmaker | Solve-a-thon organizers (Downloads) | 2026-11-06 | Notes: `src/docs/organizer_materials_notes.md` |
| `organizer/Solveathon_Azure_Access_Guide-1.docx` | Azure login and subscription guide | Organizers | 2026-11-06 | No credentials inside |
| `organizer/Solve-a-thon-Presentation-Template.pptx` | Slide template | Organizers | 2026-11-06 | 13 slides, 6 minute talk |
| `organizer/additional-tools-1.zip` and `organizer/additional-tools/` | Two plain-text diagram skills and sample outputs | Organizers | 2026-11-06 | Read only, nothing installed or run. Examples dated 2026-10-21 |
| `agency_plans/` | 34 NC agency strategic plan PDFs, `MANIFEST.csv`, `README.md` | https://www.osbm.nc.gov/operational-excellence/strategic-planning/agency-strategic-plans | 2026-11-06 | 63 MB. Text extractability and plan years not yet checked |

## Opportunity data pulls (Nov 6, 2026; cached under `data/cache/api/`, not in `raw/`)
| Cache folder | Source | Key needed | Date | Notes |
|---|---|---|---|---|
| `grantsgov_extract/` | https://prod-grants-gov-chatbot.s3.amazonaws.com/extracts/GrantsDBExtract20261106v2.zip (linked from https://www.grants.gov/xml-extract) | no | 2026-11-06 | 75 MB zip, 307 MB XML, 83,693 records. Gitignored |
| `grantsgov/`, `grantsgov_status/` | https://api.grants.gov/v1/api (search2, fetchOpportunity) | no | qualifier cache copied; status snapshot 2026-11-06 | `grantsgov/` is about 58 MB: decide before committing |
| `simpler/` | https://api.simpler.grants.gov/v1/opportunities/search | yes (`SIMPLER_GRANTS_KEY`) | 2026-11-06 | 1,471 records. Key is never written to cache |
| `federalregister/` | https://www.federalregister.gov/api/v1/documents.json | no | 2026-11-06 | Notices, last 12 months, 3 search phrases |
| `usaspending/` | https://api.usaspending.gov/api/v2/search/spending_by_award/ | no | 2026-11-06 | NC government recipients, award types 02-05, FY2022-2026, 10,000 awards |
| not pulled | SAM.gov Assistance Listings API (the bulk file below replaces it); transportation.gov grants page | SAM key | | SAM pages 10 listings per call (2,873 listings); transportation.gov blocks scripted access (403) |

## Bulk files (Nov 7, 2026)
| Folder or file | What | Source | Date added | Notes |
|---|---|---|---|---|
| `sam_assistance_listings/AssistanceListings_DataGov_PUBLIC_CURRENT.csv` | SAM.gov Assistance Listings (CFDA catalog): 2,875 rows, 38 columns, includes Authorization (040) | GSA, CC0. https://s3.amazonaws.com/falextracts/Assistance%20Listings/datagov/AssistanceListings_DataGov_PUBLIC_CURRENT.csv | 2026-11-07 (server last-modified 2026-11-01) | 22 MB, cp1252 encoding. No API calls, no key. Read by `src/R/05b_sam_listings.R` into `data/processed/sam_listings.csv`. All 2,875 rows are kept (210 have lettered numbers such as 11.63A; 2,672 have a statutory authority). `handoff.md` says 2,873 listings; the 2-row gap is not reconciled |

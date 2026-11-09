# data/qualifier

The only two files from the earlier qualifier round (NC DHHS grant-writer triage) that the pipeline still reads. Everything else from that round is in `archive/qualifier/` and is not used.

| File | Read by | What it is |
|---|---|---|
| `agency_capabilities.csv` | `R/11_build_payload.R` via `CAPABILITIES_FILE` in `R/00_config.R` | Hand-built from public pages: what DHHS and DMVA deliver themselves. Display only. |
| `payload.json` | `R/11_build_payload.R` via `QUALIFIER_PAYLOAD` | The qualifier tool's payload. Its county and population geography (ACS 2023 5-year, CDC PLACES, HRSA, OpenFEMA) feeds the "who a grant reaches" tags. Display only. |

The county outline file the map needs, `nc_counties_tigris.rds`, is byte-identical to the copy already in `data/cache/api/`, so `R/05c_county_shapes.R` reads that copy and no second copy is kept here.

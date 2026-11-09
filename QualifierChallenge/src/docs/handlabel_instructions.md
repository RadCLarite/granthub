# How to hand-label the 60 opportunities

**What this is for.** Our tool uses a computer model to read each grant and fill in
facts like "does this need matching funds?" Your labels are the answer key. We compare
the model against you and report how often it is right. Judges care about this number.

**Rules**
1. Label from the grant itself: the abstract in the sheet, and the Grants.gov link if
   you need more. Do not ask the model, and do not look at the tool's answers first.
2. If you are unsure, pick your best answer and write why in `notes`. Unsure is useful.
3. Split the sheet however you like. Put your initials in `labeler_initials`.
4. Save the finished file as `data/manual/handlabels_60.csv` (same columns, same order).

**Time.** About 2–3 minutes per row for the required fields. Do those first.

## Required fields

| Column | What to enter | How to decide |
|---|---|---|
| `human_administrable` | TRUE / FALSE | Could a NC state health, human services, or veterans agency realistically be the lead applicant and run it? Research grants that need a university professor = FALSE. |
| `human_domain` | D01–D08 or `none` | See the list below. Pick the single best fit. |
| `human_align_dhhs` | strong / partial / none | Does it advance an objective in the DHHS 2024-26 plan (`data/manual/dhhs_priorities.csv`)? strong = directly; partial = related; none = unrelated. |
| `human_align_dmva` | strong / partial / none | Same, against the DMVA 2025-29 plan (`data/manual/dmva_priorities.csv`). |
| `human_match_required` | TRUE / FALSE | Does the text say the applicant must put in its own money (cost share, match, non-federal share)? |
| `human_capabilities` | ids separated by `;` | What would the agency have to *deliver*? Use ids from the list below. Leave blank if none apply. |

## How to decide `human_administrable`

The question is narrow: **could a North Carolina state health, human services, or veterans
agency (DHHS or DMVA) realistically be the lead applicant and run this in North Carolina?**
Answer it on its own. Whether it fits the strategic plan (alignment) and whether the agency has
the staff or capabilities (the tiers) are separate questions with their own columns.

Work through these in order. The first "no" makes it FALSE.

1. **Can a state government apply as the lead?** Read the eligibility notes, not just the list of
   applicant types. "Only the following applicant is eligible", a named incumbent, or "states may
   participate only as subrecipients" means FALSE.
2. **Is the work done in the United States?** International programs are FALSE.
3. **Is it program work rather than research?** If the award pays an investigator to study
   something (R01, U01, "research network", "investigator", "hypothesis"), FALSE. If it pays to
   deliver, build, or improve a service, keep going. Evaluation *of the funded program* is fine.
4. **Is it the kind of work a health, human services, or veterans agency does?** Law enforcement,
   wildland fire, mine cleanup, highways, economic development, arts, and agriculture are FALSE,
   even though a *different* NC agency could apply. The tool is for DHHS and DMVA writers.

If all four pass, TRUE. Examples from our data: Title X Family Planning is TRUE; global health
security in Sierra Leone is FALSE (step 2); a CDC emerging-infections research network is FALSE
(step 3); an EDA regional planning grant is FALSE (step 4); the State Veterans Home Construction
Grant is TRUE (for DMVA). Borderline example: a Justice Department opioid program open to "state
agencies" usually goes to the public-safety department, so decide whether DHHS could plausibly
lead it and say why in `notes`.

## Optional fields (if time allows)

`human_subrecipient` (passes money to other organizations?), `human_evaluation` (formal
evaluation required?), `human_capital` (construction or buying buildings?),
`human_designation` (needs the Governor or a formal state designation?),
`human_renewal` (continuation of an existing award?), `human_population` (who is served),
`human_division` (which division would own it). All TRUE/FALSE except the last two.

## Domains

D01 Behavioral health and crisis · D02 Substance use and overdose · D03 Maternal, infant
and reproductive health · D04 Child and family well-being · D05 Food and nutrition
security · D06 Aging, disability and long-term care · D07 Health access and workforce ·
D08 Public health preparedness, infectious disease and disaster · `none`

## Capability ids

clinical_service_delivery · behavioral_health_delivery · long_term_care_operation ·
public_health_surveillance · data_systems_interoperability ·
research_and_rigorous_evaluation · housing_stock_or_assistance · transportation_services ·
workforce_training_credentialing · emergency_management ·
benefits_eligibility_administration · capital_construction · laboratory_services ·
subrecipient_network_management

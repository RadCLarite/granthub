# Program domain taxonomy (v2, approved 2026-09-29)

Eight program domains. Each opportunity gets exactly one primary domain. The domain
controls two things in the tool: the user's priority weight, and which county need
layer the opportunity inherits on the map. Nearly every opportunity is statewide, so
geography weights **domains**, not individual grants.

| ID | Domain | Includes | Excludes / routes elsewhere | Main DHHS plan anchors |
|---|---|---|---|---|
| D01 | Behavioral health and crisis | Mental health services, 988, mobile crisis, suicide prevention, child behavioral health | Substance use treatment (D02) | G2.O1, G3.O1–O3, G3.O5 |
| D02 | Substance use and overdose | Opioid response, MAT/MOUD, harm reduction, overdose prevention, recovery support | Disaster "recovery" (D08) | G3.O4 |
| D03 | Maternal, infant and reproductive health | Prenatal care, doulas, family planning/Title X, congenital syphilis, perinatal quality | Early childhood education (D04) | G2.O4 |
| D04 | Child and family well-being | Child welfare, foster/kinship care, adoption, early childhood, family support | Child nutrition (D05) | G2.O2, G4.O2 |
| D05 | Food and nutrition security | WIC, SNAP/FNS, food insecurity, breastfeeding support | — | G2.O3 |
| D06 | Aging, disability and long-term care | Older adults, I/DD, disability services, long-term care facilities, veterans homes, direct care | Direct-care *workforce* programs → D07 | G1.S3.5, G3.S1.3 |
| D07 | Health access and workforce | Primary care access, rural health, telehealth/broadband, health and caregiving workforce, CHWs | Behavioral-health-specific workforce → D01 | G1.O3, G1.O4, G4.O1, G4.O4 |
| D08 | Public health preparedness, infectious disease and disaster | Surveillance, labs, infectious disease, emergency preparedness, hazard mitigation, disaster recovery | — | G1.O2, G3.S5.2 |

**Disambiguation rule kept from v1:** "recovery" alone → D02. It becomes D08 only
with hurricane, flood, disaster, FEMA or hazard mitigation nearby.

**Why v2 differs from v1:** v1 had no home for long-term care and aging (the bridge
between DHHS and DMVA), treated rural/telehealth — a delivery mode — as a domain,
and had no home for infectious disease and surveillance, a large share of CDC
opportunities. Rural and telehealth are now inside D07; disaster is merged with
preparedness in D08.

# Assumptions & Open Questions: Federal Funds Matchmaker (Architecture & Security)

Version 1.0 · 2026-10-21 · Confirm or correct each item, then regenerate the diagrams.

## Assumptions
| # | Assumption | Why we assumed it | Confirm with |
|---|---|---|---|
| A1 | The database is **Azure Cosmos DB (NoSQL)** | Deck slide 7 says "database" only | Team dev lead |
| A2 | Users sign in with **Entra ID** via App Service authentication | State-government norm; not shown in code | Team dev lead |
| A3 | **Application Insights** is enabled on the Web App and Function App | Default for new Azure resources | Azure portal |
| A4 | All ingested data is **public**; no internal agency notes are stored | Sources are public APIs/PDFs | OSBM sponsor |
| A5 | The SAM.gov API key is currently in `.env` (not Key Vault) | Found `SAM_API_KEY=****` in `.env.example` | Team dev lead |
| A6 | Azure AI Search is **not** yet built (shown as recommended) | No SDK reference found | Team |

## Open questions
1. Who may change scoring weights, and is there an approval step?
2. What is the retention period for raw payloads and PDFs?
3. Will a real pilot use state-tenant identities or a separate test tenant?
4. Is there a labelled set of "good matches" to measure accuracy?

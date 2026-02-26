# Data Flow Diagram

```mermaid
flowchart LR
  UI[Client UI<br/>\(macOS/iOS/Windows/Android\)] -->|HTTP/JSON| API[Backend/API]
  API -->|SQL| DB[(PostgreSQL)]
  DB --> ledger[ledger]
  DB --> account[account]
  DB --> tx[transaction]
  DB --> split[split]
  DB --> commodity[commodity]
  DB --> templates[coa_template & coa_template_node]

  templates -->|instantiate| account
  commodity -->|currency reference| ledger
  tx --> split
  split --> account
```

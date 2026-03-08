# Data Flow Diagram

``` mermaid
flowchart TD
  subgraph Clients
    UI["Client UI\nmacOS / iOS / Android / Web"]
  end

  subgraph Import["Import Pipeline (offline)"]
    XLS_ISO["SIX ISO 4217 Excel"]
    XLS_COA["COA Template Excel\n(Meta + Nodes sheets)"]
    PY_ISO["iso4217_importer_script.py"]
    PY_COA["coa_importer_script.py"]
  end

  subgraph API["Backend API — Spring Boot 3.x / Java 23"]
    JwtFilter["JwtAuthFilter\n(validates Bearer token)"]
    Controllers["Controllers\nAuth · Health · Ledger · Account\nCommodity · Transaction"]
    Services["Services\nBusiness logic · ownerID resolution"]
    TenantCtx["TenantContext\nSET LOCAL app.current_owner_id"]
    Repos["Repositories\nNamedParameterJdbcTemplate"]
  end

  subgraph DB["PostgreSQL"]
    commodity["commodity\n(CURRENCY / CRYPTO)"]
    coa_template["coa_template\ncoa_template_node"]
    account_type["account_type\n(catalog)"]
    ledger["ledger"]
    account["account"]
    tx["transaction"]
    split["split"]
    audit["audit_log"]
  end

  XLS_ISO --> PY_ISO --> commodity
  XLS_COA --> PY_COA --> coa_template

  UI -->|"HTTP + Bearer JWT"| JwtFilter
  JwtFilter --> Controllers
  Controllers --> Services
  Services --> TenantCtx
  TenantCtx -->|"BEGIN · SET LOCAL · query · COMMIT"| Repos
  Repos -->|"mab_post_transaction()"| tx
  Repos -->|"create_ledger_with_optional_template()"| ledger
  Repos -->|"SELECT"| account
  Repos -->|"SELECT"| commodity
  tx --> split
  split -.->|"trg_audit"| audit
  tx -.->|"trg_audit"| audit
  ledger -.->|"trg_audit"| audit
  account -.->|"trg_audit"| audit
```

---

## Import Pipeline Detail

``` mermaid
flowchart LR
  subgraph ISO4217
    A["download_iso4217_current_to_excel.py\nFetches SIX list-one.xls"]
    B["iso4217_importer_script.py\nUpserts into commodity"]
    A --> B
  end

  subgraph COA
    C["COA Template Excel\n(Meta sheet + Nodes sheet)"]
    D["coa_importer_script.py v2\nReads metadata from Meta sheet\nUpserts coa_template + coa_template_node"]
    C --> D
  end

  B --> commodity[(commodity)]
  D --> coa_template[(coa_template\ncoa_template_node)]
```

---

## Ledger Creation + Template Instantiation

``` mermaid
flowchart TD
  A["POST /ledgers\n(LedgerController)"]
  B["LedgerService\nResolve ownerID from JWT"]
  C["TenantContext.withOwner()"]
  D["LedgerRepository\ncreate_ledger_with_optional_template()"]
  E{"Template provided?"}
  F["instantiate_coa_template_to_ledger()"]
  G["INSERT accounts (ordered by level)\nResolve parent_id via temp mapping table"]
  H["UPDATE ledger.root_account_id"]
  I["Return LedgerResponse"]

  A --> B --> C --> D --> E
  E -- Yes --> F --> G --> H --> I
  E -- No --> I
```

---

## Transaction Posting Flow

``` mermaid
flowchart TD
  A["POST /transactions\n(TransactionController)"]
  B["TransactionService\nResolve ownerID from JWT"]
  C["TenantContext.withOwner()"]
  D["TransactionRepository\nBuild splits JSONB via Jackson"]
  E["mab_post_transaction()\n(PostgreSQL function)"]
  F["pg_advisory_xact_lock\n(per-ledger concurrency control)"]
  G["Validate accounts · balance check · memo rule"]
  H["INSERT transaction + splits"]
  I["trg_audit fires → audit_log"]
  J["Fetch full TransactionResponse"]
  K["Return HTTP 201"]

  A --> B --> C --> D --> E --> F --> G --> H --> I --> J --> K
```

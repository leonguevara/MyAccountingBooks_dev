# 📘 MyAccountingBooks — Technical Database Architecture Summary

This document consolidates **all database-related work completed so far**, including modeling decisions, accounting semantics, data pipelines, and deployment posture.

---

## 1. 🎯 Architectural Goal

We are building a **cross-platform accounting engine**, not just an app database.

### Target runtime environments

| Layer             | Technology                            |
| ----------------- | ------------------------------------- |
| Apple platforms   | Swift / SwiftUI (macOS, iOS, watchOS) |
| Android / Desktop | Java / Kotlin                         |
| Backend API       | Java (Spring-style service layer)     |
| Persistence       | PostgreSQL (single source of truth)   |

> CoreData is now strictly a **local cache/offline persistence layer**, not the system of record.

---

## 2. 🧠 Foundational Design Principle

**The database itself enforces accounting correctness.**

This means:

* Structural validation lives in SQL
* Templates are versioned data, not files
* Posting rules are enforced transactionally
* Clients cannot corrupt accounting state

We are intentionally modeling the system closer to:

> a General Ledger engine (e.g., SAP / Oracle Financials)
> than a CRUD application.

---

## 3. 📊 Multi-Tenant Model (Future-Proofed SaaS)

Even though usage begins as *single-user multi-device*, the schema is SaaS-ready.

``` text
ledger_owner 1 ── N ledger 1 ── N accounts
```

Each user:

* owns multiple ledgers
* each ledger is logically isolated

No redesign required when scaling to thousands of users.

---

## 4. 📚 Chart-of-Accounts Template System (Key Innovation)

We abandoned JSON-driven account creation and replaced it with **database-managed templates**.

### Core Tables

#### `coa_template`

Defines a full accounting catalog:

* country / jurisdiction
* versioning
* base language
* accounting standard (SAT, IFRS, custom)

#### `coa_template_node`

Defines each account node:

* hierarchical structure
* ordering and levels
* placeholder semantics
* account classification via `account_type_code`

Templates are:

* versioned
* importable
* instantiable atomically

---

## 5. 🔁 Ledger Instantiation Pipeline

Ledger creation is now a **database operation**, not client logic.

``` cpp
create_ledger()
   → instantiate_coa_template()
        → materialize account tree
```

This guarantees:

* Referential integrity
* Deterministic structure
* Auditability
* Identical results across platforms

---

## 6. 🧾 Semantic Separation: Kind vs Type vs Role

A major conceptual clarification.

| Dimension   | Meaning                   | Example              |
| ----------- | ------------------------- | -------------------- |
| AccountKind | Accounting nature         | Asset                |
| AccountType | Functional classification | Checking Account     |
| AccountRole | Operational usage         | Control / Tax / Memo |

This enables:

* Correct reporting logic
* Regulatory mapping (SAT)
* Flexible UI representation
* Future extensions without schema change

---

## 7. 💱 Commodity System (Currencies, Crypto, Assets)

`commodity` is designed as a generalized financial instrument table.

``` cpp
namespace:
  CURRENCY
  CRYPTO
  (future: SECURITY, COMMODITY, etc.)
```

Loaded using ISO-4217 authoritative data.

Key fields:

* mnemonic (USD, MXN, BTC)
* fraction (precision)
* revision (sync support)
* soft deletion
* namespace isolation

---

## 8. 🇲🇽 SAT Compliance — Without Hard Coupling

We deliberately avoided baking SAT codes into core accounts.

Instead:
→ Mapping is ledger-specific.

This allows:

* Personal accounting without SAT
* Business accounting with SAT
* Multi-jurisdiction future expansion

---

## 9. 🌐 Internationalization at the Data Level

Localization is not UI-only.

Templates are language-neutral and can support:

``` text
coa_template_node_label
(language_code, localized_name)
```

This allows:

* Same ledger structure
* Different language rendering

---

## 10. 🔐 Identity Model Supports Multiple Login Providers

User identity supports account linking:

``` text
ledger_owner
auth_identity
```

Enables:

* email/password login
* Google / Apple / GitHub federation

Without duplicating ledger ownership.

---

## 11. 🧮 Exact Arithmetic Model (No Floating Point)

All monetary values modeled using rational arithmetic:

``` text
value_num / value_denom
quantity_num / quantity_denom
```

This prevents:

* Rounding drift
* FX precision errors
* Ledger imbalance

---

## 12. 📥 Controlled Data Import Pipeline

All external data flows through a staging process:

``` text
Excel → Normalized JSON → Staging Tables → Validation → Insert
```

No direct inserts allowed.

This ensures:

* Deterministic imports
* Template version traceability
* Schema validation before commit

---

## 13. 🏗 Clean DDL Generation

We produced a consolidated schema creation script:

``` text
000Y_MyAccountingBooks_CreateFromScratch_NoAlters.sql
```

Purpose:

* Reproducible environment creation
* CI/CD friendly
* Clean deployments
* No migration-history dependency

---

## 14. ☁️ Deployment Strategy (Cloud-Agnostic)

Schema intentionally avoids vendor lock-in.

Compatible with:

* Local PostgreSQL (dev)
* DigitalOcean Managed PG (initial prod)
* AWS RDS migration (future scale)

---

## 15. 📍 Current System Status

| Area                 | Status        |
| -------------------- | ------------- |
| Data Model           | ✔ Stable      |
| Templates            | ✔ Operational |
| Import Pipelines     | ✔ Working     |
| ISO Currency Dataset | ✔ Loaded      |
| Crypto Support       | ✔ Seeded      |
| SAT Alignment        | ✔ Designed    |
| Ledger Instantiation | ✔ SQL-Based   |
| DDL Bootstrap        | ✔ Complete    |
| Posting Engine       | 🚧 Next Phase |

---

## 16. 🚀 Next Major Milestone

We now move into the **Posting Engine**, which will define:

* Transaction validation rules
* Double-entry enforcement
* Memo-account logic
* Reversal/void semantics
* Concurrency-safe posting
* Balance computation strategy

This is the **true accounting core**.

---

✅ Once you share the table descriptions (`\d account`, `\d transaction`, `\d split`), I will generate the first production version of the posting engine functions aligned exactly to your schema.

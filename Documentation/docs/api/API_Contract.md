# API Contract Documentation (Future)

**Last updated:** 2026-03-01  
**Status:** Placeholder — backend API not yet implemented

---

## Planned Backend

A Java/Spring Boot (or Swift server-side) service layer will expose the accounting engine via REST/JSON.

The API will wrap these database functions:

| HTTP Endpoint              | DB Function                                   |
|----------------------------|-----------------------------------------------|
| `POST /ledgers`            | `create_ledger_with_optional_template()`      |
| `POST /transactions`       | `mab_post_transaction()`                      |
| `POST /transactions/{id}/reverse` | `mab_reverse_transaction()`          |
| `POST /transactions/{id}/void`    | `mab_void_transaction()`             |
| `GET  /ledgers/{id}/accounts`     | Direct query on `account`            |
| `GET  /ledgers/{id}/transactions` | Direct query on `transaction`        |

---

## OpenAPI Spec

See [`openapi.yaml`](openapi.yaml) for the draft contract.

---

## Authentication Flow

1. Client authenticates (email/password or OAuth provider).
2. Backend resolves `ledger_owner.id`.
3. Backend sets `SET LOCAL app.current_owner_id = '<uuid>'` at the start of every database session.
4. PostgreSQL RLS policies enforce tenant isolation automatically.

All database queries run as `mab_app` role. The `app.current_owner_id` session variable is the sole mechanism for tenant scoping.

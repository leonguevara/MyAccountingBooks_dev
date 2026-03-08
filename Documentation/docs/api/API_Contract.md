# API Contract

**Status:** ✅ Implemented  
**Last updated:** 2026-03-07  
**Runtime:** Spring Boot 3.x · Java 23 · Port 8080  
**Swagger UI:** `http://localhost:8080/swagger-ui.html`  
**OpenAPI JSON:** `http://localhost:8080/v3/api-docs`

---

## Base URL

``` url
http://localhost:8080        (local / Docker)
```

---

## Authentication

All endpoints except `/health` and `POST /auth/login` require a JWT bearer token.

**Obtain token:**

``` http
POST /auth/login
Content-Type: application/json

{ "email": "user@example.com", "password": "secret" }
```

**Response:**

``` json
{ "token": "eyJhbGci...", "ownerID": "<uuid>" }
```

**Use token:**

``` bash
Authorization: Bearer <token>
```

Tokens are valid for 24 hours (configurable via `jwt.expiration-ms`).

---

## Endpoints

### Health

| Method | Path      | Auth | Description                                   |
|--------|-----------|------|-----------------------------------------------|
| GET    | `/health` | No   | Liveness probe — returns `{ "status": "ok" }` |

---

### Auth

| Method | Path           | Auth | Description                   |
|--------|----------------|------|-------------------------------|
| POST   | `/auth/login`  | No   | Authenticate, receive JWT     |

**Request:**

``` json
{ "email": "string", "password": "string" }
```

**Response `200`:**

``` json
{ "token": "string", "ownerID": "uuid" }
```

---

### Ledgers

| Method | Path       | Auth | Description                                        |
|--------|------------|------|----------------------------------------------------|
| GET    | `/ledgers` | JWT  | List all ledgers for the authenticated owner       |
| POST   | `/ledgers` | JWT  | Create a new ledger (optionally from COA template) |

**POST /ledgers — Request:**

``` json
{
  "name": "Personal 2026",
  "currencyCommodityId": "<uuid>",
  "coaTemplateCode": "PERSONALES_2026",
  "coaTemplateVersion": "1",
  "decimalPlaces": 2
}
```

`coaTemplateCode` and `coaTemplateVersion` are optional. If omitted, the ledger is created with no accounts.

**Response `201`:**

``` json
{
  "id": "<uuid>",
  "name": "Personal 2026",
  "currencyCommodityId": "<uuid>",
  "currencyCode": "MXN",
  "decimalPlaces": 2,
  "isActive": true,
  "createdAt": "2026-03-08T00:00:00Z"
}
```

---

### Accounts (Chart of Accounts)

| Method | Path                           | Auth | Description                              |
|--------|--------------------------------|------|------------------------------------------|
| GET    | `/ledgers/{ledgerId}/accounts` | JWT  | Returns the flat COA list for a ledger   |

Accounts are ordered by `code ASC`. Use `parentId` on each item to reconstruct the tree client-side.

**Response `200` — array of:**

``` json
{
  "id": "<uuid>",
  "code": "101-001000000-000000",
  "name": "Efectivo",
  "parentId": "<uuid | null>",
  "kind": 1,
  "accountTypeCode": "CASH",
  "isPlaceholder": false,
  "isActive": true
}
```

---

### Commodities

| Method | Path                              | Auth | Description                                        |
|--------|-----------------------------------|------|----------------------------------------------------|
| GET    | `/commodities`                    | JWT  | List all active commodities                        |
| GET    | `/commodities?namespace=CURRENCY` | JWT  | Filter by namespace (`CURRENCY`, `CRYPTO`)         |
| GET    | `/commodities/{id}`               | JWT  | Get a single commodity by UUID                     |

**Response `200` — array of:**

``` json
{
  "id": "<uuid>",
  "mnemonic": "MXN",
  "namespace": "CURRENCY",
  "fullName": "Mexican Peso",
  "fraction": 100,
  "isActive": true
}
```

> The `fraction` field equals the correct `valueDenom` to use in splits for that currency. Example: `fraction=100` → use `valueDenom: 100` in transactions.

---

### Transactions

| Method | Path                                       | Auth | Description                           |
|--------|--------------------------------------------|------|---------------------------------------|
| POST   | `/transactions`                            | JWT  | Post a double-entry transaction       |
| POST   | `/transactions/{id}/reverse`               | JWT  | Reverse a transaction                 |
| POST   | `/transactions/{id}/void`                  | JWT  | Void a transaction                    |

**POST /transactions — Request:**

``` json
{
  "ledgerId": "<uuid>",
  "currencyCommodityId": "<uuid>",
  "postDate": "2026-03-08T00:00:00Z",
  "memo": "Monthly rent",
  "splits": [
    { "accountId": "<uuid>", "side": 0, "valueNum": 1500000, "valueDenom": 100, "memo": "Rent expense" },
    { "accountId": "<uuid>", "side": 1, "valueNum": 1500000, "valueDenom": 100, "memo": "Bank account" }
  ]
}
```

**Rational arithmetic rule:** `side=0` is DEBIT, `side=1` is CREDIT. All splits must share the same `valueDenom`. `SUM(valueNum WHERE side=0)` must equal `SUM(valueNum WHERE side=1)`.

**Response `201`:**

``` json
{
  "id": "<uuid>",
  "ledgerId": "<uuid>",
  "currencyCommodityId": "<uuid>",
  "postDate": "2026-03-08T00:00:00Z",
  "enterDate": "2026-03-08T00:00:00Z",
  "memo": "Monthly rent",
  "isVoided": false,
  "splits": [
    { "id": "<uuid>", "accountId": "<uuid>", "side": 0, "valueNum": 1500000, "valueDenom": 100, "memo": "Rent expense" },
    { "id": "<uuid>", "accountId": "<uuid>", "side": 1, "valueNum": 1500000, "valueDenom": 100, "memo": "Bank account" }
  ]
}
```

**POST /transactions/{id}/reverse — Request:**

``` json
{ "memo": "Reversal — wrong account" }
```

**POST /transactions/{id}/void — Request:**

``` json
{ "reason": "Duplicate entry" }
```

---

## Error Model

All errors return:

``` json
{
  "status": 422,
  "error": "UNPROCESSABLE_ENTITY",
  "message": "Transaction splits do not balance"
}
```

| HTTP | Meaning                                                  |
|------|----------------------------------------------------------|
| 400  | Bad request or DB invariant violation (mab__assert)      |
| 401  | Missing or invalid JWT                                   |
| 404  | Resource not found or not owned by caller                |
| 409  | Conflict (already voided, already reversed)              |
| 500  | Unexpected internal error                                |

---

## Security Notes

- `ownerID` is **always** resolved from the JWT — never from request parameters.
- Every DB query runs inside `TenantContext.withOwner()`, which sets `SET LOCAL app.current_owner_id` before any SQL executes.
- PostgreSQL RLS provides a second enforcement layer: even if the application layer were bypassed, the DB would return zero rows for another owner's data.
- The API connects to PostgreSQL as the `mab_app` role (DML only, no DDL, no TRUNCATE).

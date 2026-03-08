# Backend API Architecture

**Last updated:** 2026-03-07  
**Runtime:** Spring Boot 3.5 · Java 23  
**Module:** `MAB-API/`

---

## Overview

The MAB API is a stateless Spring Boot REST service that wraps the PostgreSQL accounting engine. It is intentionally thin at every layer: all accounting correctness lives in the database. The API's sole responsibilities are authentication, tenant scoping, HTTP routing, and result serialization.

---

## Technology Stack

| Concern              | Technology                                   |
|----------------------|----------------------------------------------|
| Framework            | Spring Boot 3.5 (Tomcat embedded)            |
| Language             | Java 23                                      |
| Build                | Maven (mvnw wrapper)                         |
| DB access            | NamedParameterJdbcTemplate (Spring JDBC)     |
| Auth                 | JWT via JJWT 0.12.6 (HMAC-SHA256)            |
| API docs             | springdoc-openapi 2.8.6 (OpenAPI 3 / Swagger)|
| Containerization     | Docker + Docker Compose                      |
| Connection pool      | HikariCP (Spring Boot auto-configured)       |

---

## Package Structure

``` diagram
com.leonguevara.mab.mab_api
├── config/
│   ├── DataSourceConfig.java      — NamedParameterJdbcTemplate + TransactionTemplate beans
│   ├── OpenApiConfig.java         — Swagger UI metadata + global JWT security scheme
│   ├── SecurityConfig.java        — Spring Security filter chain (CSRF off, stateless, public routes)
│   └── TenantContext.java         — Core RLS scoping utility (see below)
├── controller/
│   ├── AuthController.java        — POST /auth/login (public)
│   ├── HealthController.java      — GET /health (public)
│   ├── LedgerController.java      — GET /ledgers, POST /ledgers
│   ├── AccountController.java     — GET /ledgers/{id}/accounts
│   ├── CommodityController.java   — GET /commodities, GET /commodities/{id}
│   └── TransactionController.java — POST /transactions, /reverse, /void
├── service/
│   ├── AuthService.java           — Email/BCrypt login, JWT issuance, last_login_at update
│   ├── LedgerService.java         — ownerID resolution + ledger CRUD delegation
│   ├── AccountService.java        — Ledger ownership check + account list delegation
│   ├── CommodityService.java      — Commodity catalog queries
│   └── TransactionService.java    — Transaction post/reverse/void delegation
├── repository/
│   ├── LedgerRepository.java      — Queries v_ledger; calls create_ledger_with_optional_template()
│   ├── AccountRepository.java     — Queries account + account_type JOIN; flat list by code
│   ├── CommodityRepository.java   — Queries commodity by namespace/id
│   └── TransactionRepository.java — Calls mab_post_transaction(), mab_reverse_transaction(), mab_void_transaction(); fetches back result
├── security/
│   ├── JwtUtil.java               — Token generation, validation, ownerID extraction
│   ├── JwtAuthFilter.java         — OncePerRequestFilter: validates Bearer token per request
│   └── UserPrincipal.java         — Immutable record(UUID ownerID) stored in SecurityContext
├── dto/
│   ├── request/
│   │   ├── LoginRequest.java
│   │   ├── CreateLedgerRequest.java
│   │   ├── PostTransactionRequest.java
│   │   ├── ReverseTransactionRequest.java
│   │   └── VoidTransactionRequest.java
│   └── response/
│       ├── TokenResponse.java
│       ├── LedgerResponse.java
│       ├── AccountResponse.java
│       ├── CommodityResponse.java
│       └── TransactionResponse.java   — nested SplitResponse list
└── exception/
    ├── ApiException.java              — RuntimeException carrying HttpStatus + message
    └── GlobalExceptionHandler.java    — @RestControllerAdvice: ApiException, DataIntegrityViolationException, UncategorizedSQLException → structured JSON
```

---

## Security Architecture

### JWT Authentication Flow

``` diagram
Client → POST /auth/login → AuthService
  → Query ledger_owner by email (active, not deleted)
  → BCrypt verify password_hash
  → UPDATE last_login_at
  → JwtUtil.generateToken(ownerID) → JWT (HS256, 24h)
  → Return TokenResponse { token, ownerID }
```

On subsequent requests:

``` diagram
Client → Authorization: Bearer <token>
  → JwtAuthFilter.doFilterInternal()
  → JwtUtil.isValid(token) → true/false
  → JwtUtil.extractOwnerID(token) → UUID
  → SecurityContextHolder.setAuthentication(new UserPrincipal(ownerID))
  → Controller resolves principal via SecurityContextHolder
```

### TenantContext — The RLS Bridge

`TenantContext.withOwner(ownerID, jdbc, tx, work)` is the single mandatory wrapper for all authenticated DB queries. It:

1. Opens a JDBC transaction (`BEGIN`).
2. Executes `SET LOCAL app.current_owner_id = '<uuid>'`.
3. Runs the repository lambda inside the same transaction.
4. Commits on success, rolls back on any exception.

Without this, PostgreSQL RLS policies return zero rows for all tenant-scoped tables (`ledger`, `account`, `transaction`, `split`, `payee`, `scheduled_transaction`).

The `SET LOCAL` scope guarantees the variable is never visible outside the transaction — connection-pool reuse cannot leak one owner's context to another request.

### Database Role

The API connects as `mab_app`:

- DML only (SELECT, INSERT, UPDATE on financial tables)
- No DDL, no TRUNCATE
- No BYPASSRLS — RLS is always active
- `audit_log`: INSERT only (trigger populates it; app never writes directly)

---

## Error Handling

`GlobalExceptionHandler` converts all exceptions to a uniform JSON body:

``` json
{ "status": 400, "error": "BAD_REQUEST", "message": "..." }
```

Three handler cases:

- `ApiException` → service-level errors (401, 404, 409)
- `DataIntegrityViolationException` → DB constraint violations → HTTP 400
- `UncategorizedSQLException` → PostgreSQL `RAISE EXCEPTION` from `mab__assert()` inside posting functions → HTTP 400

This means posting engine invariant violations (unbalanced splits, wrong ledger, etc.) surface cleanly as HTTP 400 with the PostgreSQL error message.

---

## Docker Deployment

| File                                                       | Purpose                                                            |
|------------------------------------------------------------|--------------------------------------------------------------------|
| `MAB-API/Dockerfile`                                       | Multi-stage build: Maven + JDK 23 builder → JRE 23 runtime image   |
| `MAB-API/docker-compose.yml`.                              | Two services: `postgres` (PostgreSQL 18) + `mab-api` (Spring Boot) |
| `MAB-API/src/main/resources/application.properties`        | Default configuration (local dev, port 8080)                       |
| `MAB-API/src/main/resources/application-docker.properties` | Docker profile override: datasource URL uses `postgres` hostname   |

The `postgres` service exposes port `5433` on the host (to avoid conflicts with a local PostgreSQL on `5432`).

**Note:** The database is not auto-seeded on first run. Schema + seed data must be applied manually (see [`docs/api/API_Quick_Start.md`](API_Quick_Start.md)).

---

## OpenAPI / Swagger UI

Available at runtime:

- **Swagger UI:** `http://localhost:8080/swagger-ui.html`
- **OpenAPI JSON:** `http://localhost:8080/v3/api-docs`

All controllers are annotated with `@Tag`, `@Operation`, and `@ApiResponses`. The `bearerAuth` JWT scheme is applied globally; `/auth/login` and `/health` override it with `@SecurityRequirements({})`.

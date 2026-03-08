# MyAccountingBooks API — Engineering Postmortem

**Document type:** Technical Postmortem  
**Scope:** MAB-API — Spring Boot 3.x / Java 23 REST Backend  
**Period covered:** 2026-03-04 to 2026-03-07  
**Author:** León Felipe Guevara Chávez  
**Last updated:** 2026-03-08  
**Status:** ✅ Complete

---

## 1. Executive Summary

This document records all significant technical incidents encountered during the development of the MyAccountingBooks REST API (`MAB-API`), a Spring Boot 3.x / Java 23 service that wraps a PostgreSQL double-entry accounting engine. Seven distinct incident categories are documented, covering Spring Boot autoconfiguration conflicts, Docker networking and volume problems, PostgreSQL RLS integration, exception propagation from stored functions, and Java language-level quirks. Each incident includes a symptom description, root cause analysis, and resolution. A lessons-learned section concludes the document.

---

## 2. Incident Summary Table

| ID   | Category                      | Symptom                                                                                                      | Severity    |
|------|-------------------------------|--------------------------------------------------------------------------------------------------------------|-------------|
| I-01 | Spring Boot Autoconfiguration | `UnsatisfiedDependencyException` on startup — application crashes immediately                                | 🔴 Critical |
| I-02 | Docker / Networking           | API container cannot reach PostgreSQL — `Failed to obtain JDBC Connection`.                                  | 🔴 Critical |
| I-03 | Docker / Volume               | PostgreSQL data directory misconfigured — container fails to initialize.                                     | 🟠 High.    |
| I-04 | Spring Security               | Auto-generated password warning on every startup; `inMemoryUserDetailsManager` active                        | 🟡 Medium   |
| I-05 | RLS / TenantContext           | All authenticated queries return zero rows — RLS silently blocks all data.                                   | 🔴 Critical |
| I-06 | Exception Handling            | PostgreSQL `RAISE EXCEPTION` from posting functions surfaces as HTTP 500 instead of 400                      | 🟠 High     |
| I-07 | Java / JDBC                   | `queryForObject()` nullability warning causes compiler noise; unused RowMapper parameter causes IDE warnings | 🟢 Low      |

---

## 3. Incident Details

---

### I-01 — Spring Data JDBC Autoconfiguration Conflict

**Date discovered:** 2026-03-04  
**Phase:** First Docker build attempt

#### Symptom

The application crashed immediately on startup with the following exception chain (observed across multiple consecutive Docker build iterations throughout 2026-03-07):

``` diagram
UnsatisfiedDependencyException: Error creating bean with name 'jdbcMappingContext'
  → Error creating bean with name 'jdbcCustomConversions'
    → Error creating bean with name 'jdbcDialect'
      → Failed to obtain JDBC Connection
```

The error appeared even when the PostgreSQL container was healthy and accepting connections. The application was observed attempting to start, printing the Spring Boot banner, initializing Tomcat on port 8080, and then crashing before the web server could serve any request.

#### Root Cause

The project included `spring-boot-starter-data-jdbc` in its `pom.xml`. This dependency activates **Spring Data JDBC autoconfiguration**, which attempts to detect the database dialect by opening a live JDBC connection at application startup — before any route or repository is invoked. When the Spring Data JDBC dialect resolver could not obtain a connection (due to a misconfigured datasource URL or a container not yet ready), it threw `Failed to obtain JDBC Connection`, which cascaded up through the Spring bean initialization chain as `UnsatisfiedDependencyException`.

The misleading part of the error was that `jdbcMappingContext` and `jdbcCustomConversions` appeared as the failing beans — both of which are infrastructure beans for Spring Data JDBC repository support. Because the project uses plain `NamedParameterJdbcTemplate` (not Spring Data repositories), Spring Data JDBC was entirely unnecessary. The dependency was included as a reflex from a starter template rather than an intentional design choice.

#### Resolution

Removed `spring-boot-starter-data-jdbc` from `pom.xml`. The project uses Spring's lower-level JDBC support only:

- `spring-boot-starter-jdbc` (for `NamedParameterJdbcTemplate`, `TransactionTemplate`, and `HikariCP`)
- No Spring Data JDBC repositories are used anywhere in the codebase.

After removal, the `jdbcMappingContext` / `jdbcDialect` bean initialization no longer occurs at startup, and the application starts cleanly even with a fresh database.

**Key fix in `pom.xml`:**

```xml
<!-- REMOVED — was causing Spring Data JDBC autoconfiguration at startup -->
<!-- <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jdbc</artifactId>
</dependency> -->

<!-- CORRECT — plain Spring JDBC only -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
```

**Recurrence count:** This crash was observed in 8+ consecutive Docker start attempts across a ~45-minute debugging session, all logging identical stack traces.

---

### I-02 — Docker Container Networking: API Cannot Reach PostgreSQL

**Date discovered:** 2026-03-04  
**Phase:** Docker Compose integration

#### Symptom

After resolving I-01, the API container started but immediately failed to connect to PostgreSQL:

``` bash
HikariPool-1 - Starting...
Failed to obtain JDBC Connection
```

The same datasource URL worked perfectly from the developer's local machine (`localhost:5432`), but failed inside the Docker container.

#### Root Cause

In Docker Compose, each service runs in its own network namespace. The hostname `localhost` inside the `mab-api` container resolves to the container itself — not to the host machine or to the `postgres` service. The datasource URL in `application.properties` used `localhost:5432`, which is correct for local development but wrong inside a Docker Compose network.

Docker Compose creates a shared network where services are reachable by their **service name** as defined in `docker-compose.yml`. The PostgreSQL service is named `postgres`, so the correct JDBC URL inside the container is `jdbc:postgresql://postgres:5432/myaccounting_dev`.

#### Resolution

Implemented **Spring Boot profiles** to maintain two separate datasource configurations:

`application.properties` (local development — unchanged):

``` properties
spring.datasource.url=jdbc:postgresql://localhost:5432/myaccounting_dev
```

`application-docker.properties` (Docker runtime — new file):

``` properties
spring.datasource.url=jdbc:postgresql://postgres:5432/myaccounting_dev
spring.datasource.username=mab_app
spring.datasource.password=dev_password
```

The Docker profile is activated via the environment variable in `docker-compose.yml`:

``` yaml
environment:
  SPRING_PROFILES_ACTIVE: docker
```

And in `Dockerfile`:

``` dockerfile
ENV SPRING_PROFILES_ACTIVE=docker
```

This cleanly separates local and containerized configurations without requiring code changes.

---

### I-03 — PostgreSQL Docker Volume Mount Path

**Date discovered:** 2026-03-04  
**Phase:** Docker Compose volume configuration

#### Symptom

The `mab-postgres` container started, but data was not persisted across `docker-compose down/up` cycles. On some attempts, the container failed to initialize the PostgreSQL cluster entirely, with the container exiting immediately after start.

#### Root Cause

The Docker Compose volume mount was initially configured as:

``` yaml
volumes:
  - mab_postgres_data:/var/lib/postgresql/data
```

PostgreSQL 18 changed its default data directory path. The `postgres:18` official image initializes the cluster at `/var/lib/postgresql/data` when using the environment variable `PGDATA`, but when using the standard image without `PGDATA`, the actual data directory expected by the container is `/var/lib/postgresql` (not the `/data` subdirectory). Mounting to the wrong path meant the initialization script ran, wrote data to the unmounted path inside the container, and lost it on restart. In certain Docker Desktop configurations, this also caused the cluster initialization to fail outright.

#### Resolution

Updated the volume mount to the correct path for `postgres:18`:

```yaml
volumes:
  # PostgreSQL 18+ requires mount at /var/lib/postgresql (not /data subfolder)
  - mab_postgres_data:/var/lib/postgresql
```

A comment was added to the `docker-compose.yml` to document this non-obvious requirement for future reference.

---

### I-04 — Spring Security Auto-Generated Password Warning

**Date discovered:** 2026-03-04  
**Phase:** Security configuration

#### Symptom

On every startup, Spring Boot printed the following warning to the console:

``` text
Using generated security password: 3328468d-298f-4e94-bbf6-6077b82422eb

This generated password is for development use only. Your security
configuration must be updated before running your application in production.
```

Additionally, the log showed:

``` text
Global AuthenticationManager configured with UserDetailsService bean
with name inMemoryUserDetailsManager
```

This indicated Spring Security's default autoconfiguration was active — meaning the application was using an in-memory user store instead of the custom JWT-based authentication system being built.

#### Root Cause

Spring Boot Security autoconfiguration activates `UserDetailsServiceAutoConfiguration` by default when `spring-boot-starter-security` is on the classpath and no custom `UserDetailsService` or `SecurityFilterChain` bean is detected. During early development iterations, the `SecurityConfig` class existed but was either incomplete or not yet providing a `SecurityFilterChain` bean that fully satisfied Spring's autoconfiguration conditions. As a result, Spring fell back to its default in-memory user store and generated a random password.

The warning is harmless in the sense that the generated credentials are random and expire with each restart — but it signals that the intended security architecture is not active, which is a correctness concern during development.

#### Resolution

The root cause was addressed in two steps:

1. **Completed `SecurityConfig`**: The `SecurityFilterChain` bean was fully implemented, disabling CSRF, enforcing stateless session management, and registering `JwtAuthFilter` before Spring's default authentication filter. Once a valid `SecurityFilterChain` bean was present, Spring stopped falling back to the in-memory default.

2. **Suppressed residual `inMemoryUserDetailsManager` registration** (which persists even with a custom chain in some Spring Boot versions) by ensuring the `SecurityFilterChain` configuration was recognized as authoritative.

The warning no longer appears in the final implementation. The `inMemoryUserDetailsManager` bean is still initialized by Spring Boot (this is a known behavior), but it is not used — all authentication flows through `JwtAuthFilter` → `AuthService` → `ledger_owner` table.

**Important production note:** The `UserDetailsServiceAutoConfiguration` warning also serves as a checklist reminder. If this warning ever reappears in a deployed environment, it indicates the `SecurityConfig` bean failed to load, which is a critical security regression.

---

### I-05 — RLS Returning Zero Rows for All Authenticated Queries

**Date discovered:** 2026-03-05  
**Phase:** Repository layer development

#### Symptom

After the API started successfully and login returned a valid JWT, all subsequent authenticated API calls returned empty results:

- `GET /ledgers` → `[]`
- `GET /ledgers/{id}/accounts` → `[]`
- `GET /commodities` → `[]` (unexpected — commodity has no RLS policy)

No errors were thrown. The queries executed successfully but returned no rows.

#### Root Cause

The project's PostgreSQL schema uses Row-Level Security (RLS) on all tenant-scoped tables (`ledger`, `account`, `transaction`, `split`, etc.). The RLS policies filter rows based on the PostgreSQL session variable `app.current_owner_id`:

```sql
-- Example RLS policy on ledger
USING (owner_id = mab_current_owner_id())
```

The `mab_current_owner_id()` function reads `current_setting('app.current_owner_id', true)`. If this variable is not set, the function returns `NULL`, and `owner_id = NULL` is always false in SQL — causing all rows to be invisible to the `mab_app` role.

The initial repository implementations executed queries directly via `NamedParameterJdbcTemplate` without first setting `app.current_owner_id`. The connection pool (`HikariCP`) reuses physical connections across requests, and session-level `SET` statements would leak between requests even if they were somehow set. Neither of these was happening — the variable was simply never being set at all.

The `GET /commodities` returning empty was a separate issue: early query drafts accidentally included an unintended `WHERE` clause that filtered out all active commodities. This was a query logic error independent of RLS, but discovered at the same time.

#### Resolution

**For RLS:** Designed and implemented `TenantContext` — a static utility class that wraps every authenticated database operation in the following sequence:

```java
public static <T> T withOwner(UUID ownerID,
                               NamedParameterJdbcTemplate jdbc,
                               TransactionTemplate tx,
                               Function<NamedParameterJdbcTemplate, T> work) {
    return tx.execute(status -> {
        // SET LOCAL: scoped to this transaction only — never leaks to pool
        jdbc.getJdbcTemplate().execute(
            "SET LOCAL app.current_owner_id = '" + ownerID + "'"
        );
        return work.apply(jdbc);
    });
}
```

Key design decisions:

- `SET LOCAL` (not `SET`): the variable is scoped to the current transaction only. When the transaction commits or rolls back, the variable is automatically cleared. This prevents any possibility of the value leaking to another request via connection pool reuse.
- `TransactionTemplate`: wraps the entire block in `BEGIN / ... / COMMIT`, which is required for `SET LOCAL` to have any effect (it is a no-op outside a transaction).
- All repository methods that touch tenant-scoped tables call `TenantContext.withOwner()`. Commodity queries, which are global and not RLS-scoped, call JDBC directly without `TenantContext`.

**For the commodity query:** The erroneous `WHERE` clause was corrected separately.

---

### I-06 — PostgreSQL `RAISE EXCEPTION` Surfaces as HTTP 500

**Date discovered:** 2026-03-06  
**Phase:** Transaction posting endpoint development

#### Symptom

When `POST /transactions` was called with an intentionally unbalanced split (for testing purposes), the API returned HTTP 500 with a raw internal error message instead of a meaningful HTTP 400 with the PostgreSQL validation message.

Expected response:

```json
{ "status": 400, "error": "BAD_REQUEST", "message": "Transaction splits do not balance" }
```

Actual response:

```json
{ "status": 500, "error": "INTERNAL_SERVER_ERROR", "message": "..." }
```

#### Root Cause

The PostgreSQL posting engine functions (`mab_post_transaction()`, `mab_reverse_transaction()`, `mab_void_transaction()`) use a custom assertion helper to enforce business rules:

```sql
CREATE FUNCTION mab__assert(p_ok boolean, p_message text) ...
  RAISE EXCEPTION USING MESSAGE = p_message, ERRCODE = 'P0001';
```

When Spring JDBC executes a stored function that raises a PostgreSQL `RAISE EXCEPTION`, the exception is wrapped by Spring's JDBC exception translation. However, the translation behavior depends on the PostgreSQL error code:

- Constraint violations (e.g. `23503 FK violation`) → Spring wraps as `DataIntegrityViolationException`
- Custom `RAISE EXCEPTION` with user-defined error codes (`P0001`) → Spring wraps as `UncategorizedSQLException`

The initial `GlobalExceptionHandler` only handled `ApiException` and a generic `Exception` catch-all. It had no handler for `DataIntegrityViolationException` or `UncategorizedSQLException`. Both fell through to the generic handler, which returned HTTP 500.

#### Resolution

Added two additional `@ExceptionHandler` methods to `GlobalExceptionHandler`:

```java
// Handles FK violations and constraint errors from the DB
@ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
public ResponseEntity<Map<String, Object>> handleDataIntegrity(
        DataIntegrityViolationException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(Map.of(
            "status",  400,
            "error",   "BAD_REQUEST",
            "message", ex.getMostSpecificCause().getMessage()
        ));
}

// Handles RAISE EXCEPTION from mab__assert() inside stored functions
@ExceptionHandler(org.springframework.jdbc.UncategorizedSQLException.class)
public ResponseEntity<Map<String, Object>> handleSqlException(
        UncategorizedSQLException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(Map.of(
            "status",  400,
            "error",   "BAD_REQUEST",
            "message", ex.getMostSpecificCause().getMessage()
        ));
}
```

The handler for `UncategorizedSQLException` was the critical addition: it unwraps the Spring exception using `getMostSpecificCause()` to retrieve the original PostgreSQL error message from `mab__assert()`, and returns it as a structured HTTP 400 response. Business rule violations from the posting engine now produce clean, informative error messages to API consumers.

---

### I-07 — Java Nullability and Unused Parameter Warnings in RowMappers

**Date discovered:** 2026-03-05 – 2026-03-07  
**Phase:** Repository layer development

#### Symptom

The compiler and IDE produced two categories of warnings across all repository classes:

**Warning type A — `@SuppressWarnings("null")`:**

``` text
Return value of 'queryForObject' is annotated as @Nullable,
but used in a context where it must not be null.
```

This appeared on every call to `queryForObject()` where the result was immediately used (e.g., in `fetchTransaction()`).

**Warning type B — Unused lambda parameter:**

``` text
Variable 'rowNum' is never used.
```

This appeared in every `RowMapper` lambda where the `int rowNum` parameter (the second argument to the `(rs, rowNum) ->` signature) was not needed.

#### Root Cause

**For Warning A:** Spring's `queryForObject()` is annotated as `@Nullable` in its contract because the query could theoretically return no rows. In practice, in contexts where the row is guaranteed to exist (e.g., immediately after a successful `INSERT` returns a UUID, followed by a `SELECT` of that UUID), a null result is impossible. However, the compiler and static analysis tools cannot verify this and issue the warning.

**For Warning B:** The `RowMapper` functional interface requires a two-parameter lambda `(ResultSet rs, int rowNum)`. The `rowNum` parameter is the current row index within the result set, which is rarely needed for simple row-to-object mappings. Java prior to 21 had no syntax to suppress this — you were required to name the parameter even if unused. Java 21+ introduced unnamed variables using the `_` placeholder.

#### Resolution

**For Warning A:** Applied `@SuppressWarnings("null")` to the specific method or call site where nullability is guaranteed by context. Additionally, in `fetchTransaction()`, an explicit assertion was added:

```java
assert header != null;  // To avoid the NullPointerException.
return new TransactionResponse(header.id(), ...);
```

This satisfies both the compiler's nullability contract and provides a runtime safety net during development (JVM assertions must be enabled with `-ea` to activate).

**For Warning B:** Replaced unused `rowNum` parameters with the Java unnamed variable placeholder `_`:

```java
// Before
private static final RowMapper<LedgerResponse> LEDGER_MAPPER = (rs, rowNum) -> ...

// After
private static final RowMapper<LedgerResponse> LEDGER_MAPPER = (rs, _) -> ...
```

This syntax is valid in Java 21+ (used throughout the project per the `eclipse-temurin:23` runtime). The change was applied consistently across all RowMapper declarations in `LedgerRepository`, `AccountRepository`, `CommodityRepository`, and `TransactionRepository`. Inline comments document the reason:

```java
// Parameter rowNum is never used, so replacing it with the underscore character.
```

---

## 4. Lessons Learned

### L-01 — Spring Boot Starter Dependencies Are Not Always Additive

Adding `spring-boot-starter-data-jdbc` expecting "just the JDBC template" activates an entire autoconfiguration chain, including dialect detection at startup. When a project does not use Spring Data repositories, this dependency should be excluded. **Always audit starter dependencies before including them.** Use the minimal starter that covers actual requirements:

| Need                              | Correct starter                 |
|-----------------------------------|---------------------------------|
| `NamedParameterJdbcTemplate` only | `spring-boot-starter-jdbc`      |
| Spring Data repositories          | `spring-boot-starter-data-jdbc` |

### L-02 — Docker Service Names Are the Hostname; `localhost` Is Not

Inside a Docker Compose network, every service is reachable only by its declared service name. Any configuration using `localhost` to refer to another container will silently fail with connection errors that look identical to "database is down." **Always use Spring profiles to separate local and containerized datasource URLs.** The pattern is:

- `application.properties` → `localhost` (local dev)
- `application-docker.properties` → service name (Docker)
- `SPRING_PROFILES_ACTIVE=docker` injected via environment variable

### L-03 — Volume Mount Paths Must Match the Container's Expected Directory Exactly

Container base images often change default paths across major versions. `postgres:18` changed the expected default data path compared to earlier versions. **Always consult the official image documentation for the exact version in use**, and annotate non-obvious paths in `docker-compose.yml` with a comment explaining why the path is what it is.

### L-04 — Spring Security Autoconfiguration Is a Signal, Not Just Noise

The `inMemoryUserDetailsManager` warning is not cosmetic. If it appears in production logs, it means the custom `SecurityFilterChain` failed to load — which would make the API accessible with a random generated password. **Treat this warning as a P0 alert in any deployed environment.** Consider adding a startup check that asserts the custom security configuration is active.

### L-05 — PostgreSQL RLS Requires an Explicit Transaction Wrapper; Connection Pool Reuse Makes This Non-Trivial

`SET LOCAL` only works inside an explicit transaction. Without `TransactionTemplate` wrapping the `SET LOCAL` + query block together, RLS policies silently return zero rows for every authenticated request. **The `TenantContext.withOwner()` pattern is the only correct approach** for this architecture: it guarantees the session variable and the query execute in the same transaction, and it guarantees the variable is never leaked to subsequent requests via connection pool reuse.

Any new repository method that queries tenant-scoped tables (`ledger`, `account`, `transaction`, `split`, `payee`, `scheduled_transaction`) **must** use `TenantContext.withOwner()`. Repository methods querying global tables (`commodity`, `account_type`, `coa_template`) must not — they should query directly via `NamedParameterJdbcTemplate`.

### L-06 — Spring JDBC Exception Translation Does Not Uniformly Map PostgreSQL Errors

Spring's exception translation converts some PostgreSQL errors to typed exceptions (`DataIntegrityViolationException`) but wraps others in `UncategorizedSQLException`. The specific wrapping depends on the PostgreSQL SQLSTATE error code:

| PostgreSQL SQLSTATE                    | Spring exception                  |
|----------------------------------------|-----------------------------------|
| `23xxx` (integrity)                    | `DataIntegrityViolationException` |
| `P0001` (raise exception from plpgsql) | `UncategorizedSQLException`       |

A `GlobalExceptionHandler` must explicitly handle both types. Relying only on a generic `Exception` handler will surface all database-level business rule violations as HTTP 500, which is incorrect, uninformative, and exposes internal error detail to clients.

### L-07 — Use `_` for Unused Lambda Parameters; Use `@SuppressWarnings("null")` Surgically

Java 21+ unnamed variables (`_`) eliminate boilerplate noise from RowMapper lambdas. They should be adopted project-wide for any two-argument functional interface where the second argument is not used. `@SuppressWarnings("null")` should be applied at the narrowest possible scope (method level, not class level) and only where nullability is guaranteed by application logic — not as a blanket suppression.

### L-08 — Iterative Development Under Docker Has a High Feedback Cycle Cost

The sequence `code change → Maven compile → Docker image build → docker-compose up → read log → repeat` is significantly slower than local development. During this project, the same crash (I-01) was reproduced 8+ times while attempting incremental fixes, each full cycle taking 60–90 seconds. **Validate bean configuration issues locally first** (`mvn spring-boot:run`) before committing to Docker rebuilds. Docker is for integration testing of the networking and volume behavior — not for iterating on Spring configuration.

---

## 5. Incident Timeline

| Date       | Time (UTC) | Event                                                                 |
|------------|------------|-----------------------------------------------------------------------|
| 2026-03-04 |      —     | Initial project scaffold created (Spring Initializr)                  |
| 2026-03-04 |      —     | I-01 discovered during first `docker-compose up --build`              |
| 2026-03-04 |      -     | I-02 discovered after resolving I-01                                  |
| 2026-03-04 |      -     | I-03 discovered after resolving I-02                                  |
| 2026-03-04 |      -     | I-04 observed; noted for resolution during SecurityConfig build       |
| 2026-03-05 |      -     | I-05 discovered during `GET /ledgers` testing                         |
| 2026-03-05 |      -     | TenantContext designed and implemented                                |
| 2026-03-05 |      -     | I-07 (warning type B) identified and resolved across all repositories |
| 2026-03-06 |      -     | I-06 discovered during `POST /transactions` unbalanced split test     |
| 2026-03-06 |      -     | GlobalExceptionHandler updated with two additional handlers.          |
| 2026-03-07 |      -     | I-04 resolved via completed SecurityConfig                            |
| 2026-03-07 |      -     | I-07 (warning type A) documented and suppressed surgically            |
| 2026-03-07 |      -     | All controllers, services, and repositories complete                  |
| 2026-03-07 |      -     | Swagger UI confirmed operational at `/swagger-ui.html`                |

---

## 6. Open Items

| Item                                                                                             | Priority | Notes                                                                                    |
|--------------------------------------------------------------------------------------------------|----------|------------------------------------------------------------------------------------------|
| Replace `@SuppressWarnings("null")` with `Optional`-based patterns                               | Low      | Cosmetic; current approach is safe                                                       |
| Add startup assertion verifying `SecurityFilterChain` is the custom implementation               | Medium   | Prevents regression if autoconfiguration behavior changes in future Spring Boot versions |
| Add integration tests covering RLS isolation (two owners, cross-query attempt)                   | High     | Currently untested at the API layer                                                      |
| Replace hardcoded `SET LOCAL` string concatenation in `TenantContext` with a parameterized query | Medium   | Low actual injection risk (ownerID is a UUID from a verified JWT), but best practice     |
| Replace `Exception.getMessage()` in the generic 500 handler with a sanitized message             | Medium   | Prevents internal detail leakage in production                                           |

---

## 7. Related Documents

- [`docs/api/Backend_API_Architecture.md`](Backend_API_Architecture.md) — Package structure, security model, TenantContext pattern
- [`docs/api/API_Contract.md`](API_Contract.md) — Full endpoint reference
- [`docs/api/API_Quick_Start.md`](API_Quick_Start.md) — Developer setup guide
- [`docs/engine/Posting_Engine_Design_Specification.md`](../engine/Posting_Engine_Design_Specification.md) — `mab__assert()` and posting invariants
- [`docs/engineering/PSQL_Postmortem.md`](PSQL_Postmortem.md) — Database and import pipeline postmortem (earlier phase)
- [`CHANGELOG.md`](../../CHANGELOG.md) — Project version history

# API Quick Start — Developer Guide

**Last updated:** 2026-03-07

---

## Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin)
- PostgreSQL client (`psql`) for schema seeding
- Python 3.10+ with `psycopg[binary]`, `pandas`, `openpyxl` for data import

---

## Step 1 — Start the Stack

``` bash
cd MAB-API
docker-compose up --build
```

This starts two containers:

- `mab-postgres` — PostgreSQL 18 on host port `5433`
- `mab-api` — Spring Boot API on host port `8080`

The database starts empty. Proceed to Step 2.

---

## Step 2 — Seed the Database

Connect to the Docker PostgreSQL instance (host port `5433`):

``` bash
# Apply schema (as postgres superuser)
psql -h localhost -p 5433 -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/000_MyAccountingBooks_CreateFromScratch_v2.psql"

# Apply roles
psql -h localhost -p 5433 -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/001_roles_setup.pgsql"

# Seed account types
psql -h localhost -p 5433 -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/002_Populating_account_type.pgsql"

# Seed crypto commodities
psql -h localhost -p 5433 -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/003_seed_crypto_to_commodity.pgsql"

# Import ISO 4217 currencies
python "Python scripts/Final/download_iso4217_current_to_excel.py"
python "Python scripts/Final/iso4217_importer_script.py" \
  --dsn "host=localhost port=5433 dbname=myaccounting_dev user=postgres password=postgres_dev_password" \
  --excel iso4217_current_list_one.xlsx

# Import a COA template (example)
python "Python scripts/Final/coa_importer_script.py" \
  --dsn "host=localhost port=5433 dbname=myaccounting_dev user=postgres password=postgres_dev_password" \
  --excel "Database/Excel Files/Personales_2026.xlsx"
```

---

## Step 3 — Create a Test User

The API authenticates against `ledger_owner`. Insert a test owner directly:

``` sql
-- Connect as mab_owner (which bypasses RLS)
psql -h localhost -p 5433 -U mab_owner -d myaccounting_dev

INSERT INTO public.ledger_owner (display_name, email, password_hash)
VALUES (
  'Test User',
  'test@example.com',
  -- BCrypt hash of 'password123' — replace with your own hash
  '$2a$12$KIXoS/1XZdJkCxz8YXqB6.l6HqH3xMQDyRBc5zRpMqd5N1jgpGi7e'
);
```

To generate your own BCrypt hash (Python):

``` python
import bcrypt
print(bcrypt.hashpw(b'yourpassword', bcrypt.gensalt()).decode())
```

---

## Step 4 — Login and Get a Token

``` bash
curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' | jq .
```

Response:

``` json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "ownerID": "550e8400-e29b-41d4-a716-446655440000"
}
```

Export for subsequent calls:

``` bash
export TOKEN="eyJhbGciOiJIUzI1NiJ9..."
```

---

## Step 5 — Create a Ledger

``` bash
# Get the UUID of MXN commodity first
curl -s http://localhost:8080/commodities?namespace=CURRENCY \
  -H "Authorization: Bearer $TOKEN" | jq '.[] | select(.mnemonic=="MXN")'

# Create ledger (replace <mxn-uuid> with the id from above)
curl -s -X POST http://localhost:8080/ledgers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Finanzas Personales 2026",
    "currencyCommodityId": "<mxn-uuid>",
    "coaTemplateCode": "PERSONALES_2026",
    "coaTemplateVersion": "1",
    "decimalPlaces": 2
  }' | jq .
```

---

## Step 6 — Post a Transaction

``` bash
# Get two account IDs from the ledger
curl -s http://localhost:8080/ledgers/<ledger-uuid>/accounts \
  -H "Authorization: Bearer $TOKEN" | jq '.[] | select(.isPlaceholder==false) | {id, code, name}' | head -20

# Post a balanced transaction
curl -s -X POST http://localhost:8080/transactions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ledgerId": "<ledger-uuid>",
    "currencyCommodityId": "<mxn-uuid>",
    "postDate": "2026-03-08T00:00:00Z",
    "memo": "Prueba de asiento",
    "splits": [
      { "accountId": "<debit-account-uuid>",  "side": 0, "valueNum": 50000, "valueDenom": 100, "memo": "Cargo" },
      { "accountId": "<credit-account-uuid>", "side": 1, "valueNum": 50000, "valueDenom": 100, "memo": "Abono" }
    ]
  }' | jq .
```

---

## Step 7 — Explore Swagger UI

Open `http://localhost:8080/swagger-ui.html` in your browser. Click **Authorize**, paste the JWT token, and use the interactive docs to test all endpoints.

---

## Environment Variables

| Variable                     | Default                                     | Description                                             |
|------------------------------|---------------------------------------------|---------------------------------------------------------|
| `SPRING_PROFILES_ACTIVE`     | `docker`                                    | Activates `application-docker.properties`               |
| `JWT_SECRET`                 | `change_me_in_production_use_a_256_bit_key` | HMAC-SHA256 signing key — **must change in production** |
| `SPRING_DATASOURCE_URL`      | (from docker profile)                       | JDBC connection string                                  |
| `SPRING_DATASOURCE_USERNAME` | `mab_app`                                   | Database role                                           |
| `SPRING_DATASOURCE_PASSWORD` | `dev_password`                              | Database password                                       |

---

## Stopping and Resetting

``` bash
# Stop containers (data preserved)
docker-compose down

# Stop and wipe database volume (full reset)
docker-compose down -v
```

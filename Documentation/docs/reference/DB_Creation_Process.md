# Database Creation Process

## Option A — psql CLI

### 1. Start PostgreSQL and create role + database

```bash
psql postgres
```

```sql
-- Create project role
CREATE ROLE myaccounting_user
    LOGIN
    PASSWORD 'dev_password'
    CREATEDB;

-- Create database
CREATE DATABASE myaccounting_dev
    OWNER myaccounting_user;

\q
```

### 2. Connect as your project user

```bash
psql -U myaccounting_user myaccounting_dev
```

---

## Option B — pgAdmin 4 (EDB installer)

### 1. Create login role

Right-click **Login/Group Roles → Create → Login/Group Role**

- **General → Name:** `myaccounting_user`
- **Definition → Password:** `dev_password`
- **Privileges:** ✅ Can login, ✅ Create databases

### 2. Create database

Right-click **Databases → Create → Database**

- **Name:** `myaccounting_dev`
- **Owner:** `myaccounting_user`

### 3. Enable pgcrypto extension

Open Query Tool on `myaccounting_dev`:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

---

## Apply Schema

After creating the database, apply the schema script:

```bash
psql -h localhost -U postgres -d myaccounting_dev \
  -v ON_ERROR_STOP=1 \
  -f "SQL Scripts/Final version/000_MyAccountingBooks_CreateFromScratch_v2.psql"
```

The schema script automatically creates the `pgcrypto` extension if missing, so the manual step above is only needed for pgAdmin-only workflows.

---

## Verify

```sql
-- Connect and check tables
\c myaccounting_dev
\dt public.*

-- Or via SQL
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_type = 'BASE TABLE'
 ORDER BY table_name;
-- Expect 17 tables
```

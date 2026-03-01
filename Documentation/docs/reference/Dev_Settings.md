# Recommended Development Settings

## PostgreSQL Configuration (`postgresql.conf`)

### Locate the config file

**Homebrew:**
```bash
brew --prefix postgresql@18
# Example path: /opt/homebrew/etc/postgresql@18/postgresql.conf
```

**EDB installer (macOS):**
```
/Library/PostgreSQL/18/data/postgresql.conf
```

### Recommended minimum settings for development

```conf
shared_buffers       = 256MB
work_mem             = 16MB
maintenance_work_mem = 256MB
max_connections      = 100
log_min_duration_statement = 500   # log slow queries (ms); useful during development
```

### Restart service

```bash
# Homebrew
brew services restart postgresql@18

# EDB / system service (macOS)
sudo -u postgres pg_ctl reload -D /Library/PostgreSQL/18/data

# psql (no restart required for some settings)
SELECT pg_reload_conf();
```

---

## pgAdmin 4 Setup (EDB installer)

If using pgAdmin 4 instead of the `psql` CLI:

**Register server:**
- Host: `localhost`
- Port: `5432`
- Maintenance DB: `postgres`
- Username: `postgres`
- Password: set during EDB installation

**Enable pgcrypto extension** (via Query Tool on `myaccounting_dev`):
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

**Note:** psql meta-commands (`\copy`, `\gexec`, etc.) do **not** work in pgAdmin's Query Tool. Use only standard SQL. For imports, use the Python scripts.

---

## PATH Setup (macOS — EDB installer)

EDB does not add `psql` to the system PATH automatically:

```bash
# Add to ~/.zshrc
export PATH="/Library/PostgreSQL/18/bin:$PATH"
source ~/.zshrc

# Verify
psql --version
```

---

## Python Environment

```bash
# Install all required dependencies
pip install psycopg[binary] pandas openpyxl xlrd requests

# Verify psycopg version (must be v3)
python -c "import psycopg; print(psycopg.__version__)"
```

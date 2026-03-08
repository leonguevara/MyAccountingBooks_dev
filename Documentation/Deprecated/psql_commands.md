# PostgreSQL PSQL helpful commands

To dump the database schema:

``` psql
pg_dump -h localhost -U postgres -d myaccounting_dev --schema-only --clean --if-exists --no-owner --no-privileges -f /abosolute/path/myaccounting_dev_schema_clean.sql
```

To dump the database schema and data:

``` psql
pg_dump -h localhost -U postgres -d myaccounting_dev --format=plain --no-owner --no-privileges -f myaccounting_dev_full.sql
```

Best practice for backup format:

``` psql
pg_dump -h localhost -U postgres -d myaccounting_dev \
  --format=custom \
  --no-owner --no-privileges \
  -f myaccounting_dev.dump
```

and restore with:

``` psql
pg_restore -h localhost -U postgres -d myaccounting_dev_restored \
  --clean --if-exists \
  myaccounting_dev.dump
```

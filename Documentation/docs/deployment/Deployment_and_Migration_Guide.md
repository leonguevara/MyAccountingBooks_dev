# Deployment & Migration Guide

**Last updated:** 2026-02-27

## Environments

- Dev: psql meta-commands are acceptable.
- CI/CD: prefer SQL-only migrations.
- Prod: prefer application-layer imports; avoid meta-commands.

## Requirements

- PostgreSQL 14+
- Python 3.10+
- psycopg
- pandas
- openpyxl

## Recommended Order

1. Apply from-scratch schema
2. Apply forward migrations
3. Deploy functions (posting engine)
4. Seed commodities
5. Import COA templates
6. Run verification queries
7. Enable services

## Backup Strategy

- `pg_dump --schema-only` before migrations
- Full backup snapshots for production

# Deployment & Migration Guide

**Last updated:** 2026-02-26

## Environments

- Dev: psql meta-commands are acceptable.
- CI/CD: prefer SQL-only migrations.
- Prod: prefer application-layer imports; avoid meta-commands.

## Recommended Order

1. Apply from-scratch schema
2. Apply forward migrations
3. Deploy functions (posting engine)
4. Seed commodities
5. Import COA templates
6. Run verification queries

## Backup Strategy

- `pg_dump --schema-only` before migrations
- Full backup snapshots for production

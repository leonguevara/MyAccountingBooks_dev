# CI/CD Deployment Documentation

**Last updated:** 2026-02-26

## Pipeline

1. Start Postgres (service container)
2. Apply schema
3. Apply migrations
4. Seed reference data
5. Smoke test key functions
6. Dump schema artifact

## GitHub Actions

See `.github/workflows/db-ci.yml`.

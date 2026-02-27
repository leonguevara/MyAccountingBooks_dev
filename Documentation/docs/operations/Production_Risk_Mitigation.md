# Production Risk Mitigation

**Last updated:** 2026-02-26

- Prefer Python importers for production/CI to avoid quoting issues.
- Avoid psql meta-commands in production migrations.
- Use strict `ON_ERROR_STOP=1` and post-import validation queries.

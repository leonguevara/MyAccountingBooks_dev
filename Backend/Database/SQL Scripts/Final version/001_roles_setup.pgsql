-- =============================================================================
-- roles_setup.sql
-- Target:    myaccounting_dev (PostgreSQL 18.1)
-- Author:    Schema Review — 2026-02-27
-- Scope:     Database role definitions, privilege grants, and audit_log hardening
--
-- IMPORTANT: This script must be run as a SUPERUSER (e.g. postgres) and
--            OUTSIDE any application transaction. Role DDL (CREATE ROLE,
--            GRANT, REVOKE) cannot be rolled back.
--
-- Execution:
--   psql -U postgres -d myaccounting_dev -v ON_ERROR_STOP=1 -f roles_setup.sql
--
-- Roles defined:
--   mab_owner    — superuser-equivalent for the schema; runs migrations
--   mab_app      — runtime application role; subject to RLS
--   mab_readonly — read-only role for reporting / BI tools
--   mab_auditor  — read-only access to audit_log only
--
-- Dependency: V2 + V3 migrations must be applied before this script.
-- =============================================================================


-- =============================================================================
-- SECTION 1 · Role Creation
--             Passwords are placeholders — REPLACE before deploying.
--             Use a secrets manager (AWS Secrets Manager, Vault, etc.)
--             in production; never commit real passwords to source control.
-- =============================================================================

-- ── mab_owner ────────────────────────────────────────────────────────────────
-- Schema owner / migration runner. Has full DDL rights on the schema.
-- Used by Flyway/Liquibase and DBA operations only. Never used by the app.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mab_owner') THEN
        CREATE ROLE mab_owner
            LOGIN
            PASSWORD 'REPLACE_WITH_STRONG_SECRET_mab_owner'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION;
        RAISE NOTICE 'Role mab_owner created.';
    ELSE
        RAISE NOTICE 'Role mab_owner already exists — skipping CREATE.';
    END IF;
END;
$$;

-- ── mab_app ───────────────────────────────────────────────────────────────────
-- Runtime application role. Subject to RLS. Cannot run DDL.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mab_app') THEN
        CREATE ROLE mab_app
            LOGIN
            PASSWORD 'REPLACE_WITH_STRONG_SECRET_mab_app'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION;
        RAISE NOTICE 'Role mab_app created.';
    ELSE
        RAISE NOTICE 'Role mab_app already exists — skipping CREATE.';
    END IF;
END;
$$;

-- ── mab_readonly ─────────────────────────────────────────────────────────────
-- Reporting / BI / read-only API access. SELECT only. Also subject to RLS.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mab_readonly') THEN
        CREATE ROLE mab_readonly
            LOGIN
            PASSWORD 'REPLACE_WITH_STRONG_SECRET_mab_readonly'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION;
        RAISE NOTICE 'Role mab_readonly created.';
    ELSE
        RAISE NOTICE 'Role mab_readonly already exists — skipping CREATE.';
    END IF;
END;
$$;

-- ── mab_auditor ───────────────────────────────────────────────────────────────
-- Compliance / audit role. Can SELECT audit_log only. No access to financial data.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mab_auditor') THEN
        CREATE ROLE mab_auditor
            LOGIN
            PASSWORD 'REPLACE_WITH_STRONG_SECRET_mab_auditor'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION;
        RAISE NOTICE 'Role mab_auditor created.';
    ELSE
        RAISE NOTICE 'Role mab_auditor already exists — skipping CREATE.';
    END IF;
END;
$$;


-- =============================================================================
-- SECTION 2 · Schema Usage
-- =============================================================================

GRANT USAGE ON SCHEMA public TO mab_owner, mab_app, mab_readonly, mab_auditor;


-- =============================================================================
-- SECTION 3 · mab_owner privileges
--             Full DDL + DML rights on the schema for migration tooling.
-- =============================================================================

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO mab_owner;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mab_owner;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO mab_owner;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA public TO mab_owner;

-- Ensure future objects created by any role are accessible to mab_owner
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES    TO mab_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO mab_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON FUNCTIONS TO mab_owner;


-- =============================================================================
-- SECTION 4 · mab_app privileges
--             DML only on financial tables. No DDL. No TRUNCATE.
--             audit_log: INSERT only (trigger populates it — app never inserts directly).
--             Reference/lookup tables: SELECT only.
-- =============================================================================

-- Core financial tables: full DML
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.ledger_owner,
    public.auth_identity,
    public.ledger,
    public.account,
    public.account_type,
    public.transaction,
    public.split,
    public.payee,
    public.price,
    public.commodity,
    public.scheduled_transaction,
    public.scheduled_split,
    public.recurrence
TO mab_app;

-- Reference / lookup tables: SELECT only
GRANT SELECT ON TABLE
    public.coa_template,
    public.coa_template_node,
    public.enum_label
TO mab_app;

-- audit_log: no direct INSERT/UPDATE/DELETE from app (trigger handles it)
-- mab_app can SELECT its own owner's audit entries (RLS on audit_log
-- can be added later if needed; for now restrict at privilege level)
REVOKE ALL ON TABLE public.audit_log FROM mab_app;
GRANT SELECT ON TABLE public.audit_log TO mab_app;

-- Stored functions: app can EXECUTE all public mab_* functions
GRANT EXECUTE ON FUNCTION
    public.mab__assert(boolean, text),
    public.mab_post_transaction(uuid, jsonb, timestamp with time zone, timestamp with time zone, text, text, smallint, uuid, uuid),
    public.mab_void_transaction(uuid, text),
    public.mab_reverse_transaction(uuid, timestamp with time zone, timestamp with time zone, text),
    public.mab_current_owner_id(),
    public.create_ledger_with_optional_template(uuid, text, text, smallint, text, text, text),
    public.instantiate_coa_template_to_ledger(uuid, uuid)
TO mab_app;

-- Sequences (for gen_random_uuid via pgcrypto — implicit, but explicit is safer)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO mab_app;

-- Ensure future tables and functions get the same defaults
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mab_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO mab_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO mab_app;

-- Add after the existing mab_app grants in Section 4:
GRANT SELECT ON public.v_ledger                TO mab_app;
GRANT SELECT ON public.v_ledger_owner_redacted TO mab_app;
GRANT SELECT ON public.v_role_password_age     TO mab_app;

-- =============================================================================
-- SECTION 5 · mab_readonly privileges
--             SELECT only across all financial and reference tables.
--             No access to ledger_owner.password_hash or auth_identity credentials.
-- =============================================================================

GRANT SELECT ON ALL TABLES IN SCHEMA public TO mab_readonly;

-- Explicitly revoke sensitive credential columns via a security view
-- Direct table access to ledger_owner is replaced with a redacted view.
REVOKE SELECT ON TABLE public.ledger_owner  FROM mab_readonly;
REVOKE SELECT ON TABLE public.auth_identity FROM mab_readonly;

CREATE OR REPLACE VIEW public.v_ledger_owner_redacted AS
    SELECT
        id,
        email,
        email_verified,
        -- password_hash intentionally excluded
        display_name,
        is_active,
        created_at,
        updated_at,
        last_login_at,
        revision,
        deleted_at
    FROM public.ledger_owner;

COMMENT ON VIEW public.v_ledger_owner_redacted IS
    'Redacted view of ledger_owner: excludes password_hash. '
    'Grant this view to mab_readonly and mab_app instead of direct table access for reporting.';

GRANT SELECT ON public.v_ledger_owner_redacted TO mab_readonly;

-- No access to audit_log for readonly role
REVOKE ALL ON TABLE public.audit_log FROM mab_readonly;

-- Future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO mab_readonly;


-- =============================================================================
-- SECTION 6 · mab_auditor privileges
--             audit_log SELECT only. No access to any financial table.
-- =============================================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM mab_auditor;
GRANT SELECT ON TABLE public.audit_log TO mab_auditor;

-- No default privileges for future tables — auditor is locked to audit_log only


-- =============================================================================
-- SECTION 7 · audit_log hardening
--             Prevent any role (including mab_owner) from deleting or
--             modifying audit trail rows. Only the trigger function
--             (SECURITY DEFINER, runs as its definer) can INSERT.
-- =============================================================================

-- Revoke destructive operations from all non-superuser roles
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.audit_log FROM mab_owner;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.audit_log FROM mab_app;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.audit_log FROM mab_readonly;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE public.audit_log FROM mab_auditor;

-- mab_owner retains INSERT only (needed for direct DBA correction entries if ever required)
GRANT INSERT ON TABLE public.audit_log TO mab_owner;

-- The trigger function mab_audit_trigger() uses SECURITY DEFINER and runs as its
-- creator (mab_owner or postgres). It can INSERT into audit_log regardless of
-- the calling role's privileges — this is the correct PostgreSQL pattern for
-- append-only audit logging.


-- =============================================================================
-- SECTION 8 · Connection hardening
--             Restrict which databases each role can connect to.
--             Run as superuser.
-- =============================================================================

-- Revoke default public connect privilege from the database
-- (Replace 'myaccounting_dev' with your actual database name)
REVOKE CONNECT ON DATABASE myaccounting_dev FROM PUBLIC;

-- Grant connect explicitly to application roles only
GRANT CONNECT ON DATABASE myaccounting_dev TO mab_owner;
GRANT CONNECT ON DATABASE myaccounting_dev TO mab_app;
GRANT CONNECT ON DATABASE myaccounting_dev TO mab_readonly;
GRANT CONNECT ON DATABASE myaccounting_dev TO mab_auditor;


-- =============================================================================
-- SECTION 9 · pg_hba.conf recommendations (informational — not SQL)
-- =============================================================================

-- Add the following entries to pg_hba.conf on your PostgreSQL server.
-- Adjust IP ranges to match your deployment topology.
-- After editing, run: pg_ctl reload   (or SELECT pg_reload_conf(); in psql)
--
-- TYPE   DATABASE           USER           ADDRESS            METHOD
-- host   myaccounting_dev   mab_owner      127.0.0.1/32       scram-sha-256
-- host   myaccounting_dev   mab_app        10.0.0.0/16        scram-sha-256
-- host   myaccounting_dev   mab_readonly   10.0.0.0/16        scram-sha-256
-- host   myaccounting_dev   mab_auditor    10.0.0.0/16        scram-sha-256
--
-- For cloud deployments (AWS RDS, GCP Cloud SQL):
--   - Use SSL mode = require for all roles
--   - Restrict source IPs to your app server / VPC CIDR only
--   - mab_owner should ONLY connect from a bastion host or CI/CD runner IP


-- =============================================================================
-- SECTION 10 · RLS bypass for migration runner (mab_owner)
--              mab_owner needs to bypass RLS to seed reference data and
--              run migrations without setting app.current_owner_id.
-- =============================================================================

-- Grant BYPASSRLS to mab_owner so migrations can seed data freely.
-- This must be run as a superuser.
ALTER ROLE mab_owner BYPASSRLS;

-- mab_app and mab_readonly must NEVER have BYPASSRLS — they are always
-- subject to tenant isolation policies.
ALTER ROLE mab_app      NOBYPASSRLS;
ALTER ROLE mab_readonly NOBYPASSRLS;
ALTER ROLE mab_auditor  NOBYPASSRLS;


-- =============================================================================
-- SECTION 11 · Password rotation reminder view
--              Tracks when each role last had its password set.
--              Useful for compliance and credential rotation policies.
-- =============================================================================

CREATE OR REPLACE VIEW public.v_role_password_age AS
    SELECT
        rolname                             AS role_name,
        rolvaliduntil                       AS password_expires_at,
        CASE
            WHEN rolvaliduntil IS NULL THEN 'No expiry set — rotate manually'
            WHEN rolvaliduntil < now()  THEN 'EXPIRED'
            WHEN rolvaliduntil < now() + interval '30 days' THEN 'Expiring soon'
            ELSE 'OK'
        END                                 AS status
    FROM pg_roles
    WHERE rolname LIKE 'mab_%'
    ORDER BY rolname;

COMMENT ON VIEW public.v_role_password_age IS
    'Monitor mab_* role credential expiry. Run: SELECT * FROM v_role_password_age;';

GRANT SELECT ON public.v_role_password_age TO mab_owner;


-- =============================================================================
-- SECTION 12 · Optional: set password expiry policy
--              Uncomment and adjust interval to enforce rotation.
-- =============================================================================

-- ALTER ROLE mab_app      VALID UNTIL (now() + interval '90 days')::text;
-- ALTER ROLE mab_readonly VALID UNTIL (now() + interval '90 days')::text;
-- ALTER ROLE mab_auditor  VALID UNTIL (now() + interval '180 days')::text;
-- mab_owner rotation should be managed by your secrets manager, not VALID UNTIL.


-- =============================================================================
-- Post-setup verification queries (run manually as superuser)
-- =============================================================================
--
-- 1. List all mab_* roles and their attributes:
--    SELECT rolname, rolcanlogin, rolsuper, rolbypassrls, rolvaliduntil
--      FROM pg_roles WHERE rolname LIKE 'mab_%' ORDER BY rolname;
--
-- 2. Verify privilege grants on core tables:
--    SELECT grantee, table_name, privilege_type
--      FROM information_schema.role_table_grants
--     WHERE grantee LIKE 'mab_%'
--     ORDER BY grantee, table_name, privilege_type;
--
-- 3. Verify audit_log is protected (UPDATE/DELETE should not appear):
--    SELECT grantee, privilege_type
--      FROM information_schema.role_table_grants
--     WHERE table_name = 'audit_log'
--     ORDER BY grantee, privilege_type;
--
-- 4. Test RLS isolation as mab_app:
--    SET ROLE mab_app;
--    SET LOCAL app.current_owner_id = '';
--    SELECT COUNT(*) FROM public.ledger;   -- expect 0
--    RESET ROLE;
--
-- 5. Check password age status:
--    SELECT * FROM public.v_role_password_age;
--
-- 6. Verify mab_readonly cannot see password_hash:
--    SET ROLE mab_readonly;
--    SELECT * FROM public.ledger_owner LIMIT 1;   -- expect permission denied
--    SELECT * FROM public.v_ledger_owner_redacted LIMIT 1;  -- expect success, no hash column
--    RESET ROLE;

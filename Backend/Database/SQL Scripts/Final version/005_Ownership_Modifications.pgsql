-- -----------------------------------------------------------------------------
-- 005_Ownership_Modifications.pgsql
--
-- Purpose:
-- 1) Ensure helper function `mab_current_owner_id()` executes with caller context
--    (`SECURITY INVOKER`) so tenant resolution respects session-scoped settings.
-- 2) Assign ownership of selected public views to `mab_app` for runtime access
--    alignment after schema/object changes.
--
-- Notes:
-- - The function reads `app.current_owner_id` set by application code with
--   `SET LOCAL` inside the transaction.
-- - `missing_ok = TRUE` avoids errors when the setting is absent; NULL is
--   returned in that case.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mab_current_owner_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER          -- Must run with caller privileges (not definer).
AS $function$
    SELECT NULLIF(current_setting('app.current_owner_id', TRUE), '')::uuid;
$function$;

-- Keep operational view ownership under the application role.
ALTER VIEW public.v_ledger              OWNER TO mab_app;
ALTER VIEW public.v_ledger_owner_redacted OWNER TO mab_app;
ALTER VIEW public.v_role_password_age   OWNER TO mab_app;
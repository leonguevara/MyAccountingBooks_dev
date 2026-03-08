// ============================================================
// TenantContext.java
// Package: com.leonguevara.mab.mab_api.config
//
// Purpose: The architectural core of the API's security model.
//
//          Every authenticated database operation MUST go through
//          this class. It ensures that:
//
//            1. A transaction is opened (BEGIN).
//            2. The PostgreSQL session variable is set:
//                 SET LOCAL app.current_owner_id = '<uuid>'
//               This activates Row-Level Security (RLS) for the
//               current transaction. Without this, mab_app sees
//               zero rows in all tenant-scoped tables.
//            3. The actual repository work is executed.
//            4. The transaction is committed (COMMIT) on success
//               or rolled back (ROLLBACK) on any exception.
//
//          SET LOCAL scope: the variable only lives for the
//          duration of the current transaction. It is never
//          "leaked" to another request or connection in the pool.
//          This is PostgreSQL's built-in tenant isolation guarantee.
//
// ============================================================
// Last edited: 2026-03-04
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.config;

// NamedParameterJdbcTemplate: passed into the work function so
//   repository code can execute queries within the scoped transaction.
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

// TransactionTemplate: executes a block of code within a BEGIN/COMMIT block.
import org.springframework.transaction.support.TransactionTemplate;

// Function: a standard Java functional interface.
//   Used to pass repository logic as a lambda into withOwner().
import java.util.function.Function;

// UUID: the type of ledger_owner.id in the PostgreSQL schema.
import java.util.UUID;

public class TenantContext {

    /**
     * Executes a database operation scoped to a specific ledger_owner.
     *
     * This is the ONLY correct way to run authenticated queries.
     * All service and repository calls must go through this method.
     *
     * Usage example in a service class:
     * <pre>
     *   return TenantContext.withOwner(ownerID, jdbc, tx, template ->
     *       template.queryForList("SELECT * FROM ledger", Map.of())
     *   );
     * </pre>
     *
     * @param <T>     The return type of the database operation.
     * @param ownerID The UUID of the authenticated ledger_owner.
     *                Extracted from the JWT by JwtAuthFilter.
     * @param jdbc    The NamedParameterJdbcTemplate for executing SQL.
     * @param tx      The TransactionTemplate for wrapping in BEGIN/COMMIT.
     * @param work    A lambda containing the actual SQL query logic.
     *                Receives the jdbc template and returns a result of type T.
     * @return        The result produced by the work lambda.
     */
    public static <T> T withOwner(
            UUID ownerID,
            NamedParameterJdbcTemplate jdbc,
            TransactionTemplate tx,
            Function<NamedParameterJdbcTemplate, T> work) {

        // Execute everything inside a single database transaction.
        // TransactionTemplate handles BEGIN, COMMIT, and ROLLBACK automatically.
        return tx.execute(status -> {

            // SET LOCAL: scopes this session variable to the current transaction only.
            // PostgreSQL RLS policies read this variable via mab_current_owner_id()
            // to filter rows to only those belonging to this owner.
            // Without this line, mab_app sees ZERO rows in all tenant tables.
            jdbc.getJdbcTemplate().execute(
                    "SET LOCAL app.current_owner_id = '" + ownerID + "'"
            );

            // Execute the repository work (query, stored function call, etc.)
            // within the same transaction that has the owner scope set.
            return work.apply(jdbc);
        });
    }
}
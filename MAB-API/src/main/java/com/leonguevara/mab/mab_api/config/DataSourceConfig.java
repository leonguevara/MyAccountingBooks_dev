// ============================================================
// DataSourceConfig.java
// Package: com.leonguevara.mab.mab_api.config
//
// Purpose: Provides the NamedParameterJdbcTemplate and
//          TransactionTemplate beans used throughout the
//          repository and service layers.
//
//          Spring Boot auto-configures the DataSource and
//          HikariCP connection pool from application.properties.
//          This class builds higher-level JDBC helpers on top
//          of that auto-configured DataSource.
//
//          NamedParameterJdbcTemplate: preferred over plain
//          JdbcTemplate because it supports named parameters
//          (:ownerID, :ledgerID) instead of positional ? markers,
//          which greatly improves readability of SQL strings.
//
//          TransactionTemplate: provides programmatic transaction
//          management used by TenantContext to wrap each
//          database call in a BEGIN/COMMIT/ROLLBACK block with
//          the SET LOCAL app.current_owner_id statement.
// ============================================================

package com.leonguevara.mab.mab_api.config;

// DataSource: standard Java interface representing a connection pool.
//             Spring Boot auto-creates a HikariCP DataSource bean
//             from application.properties — we inject it here.
import javax.sql.DataSource;

// NamedParameterJdbcTemplate: Spring JDBC helper that supports
//   named parameters (:name) in SQL queries instead of ? placeholders.
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

// PlatformTransactionManager: Spring's abstraction for transaction management.
//   The DataSourceTransactionManager implementation manages JDBC transactions.
import org.springframework.transaction.PlatformTransactionManager;

// TransactionTemplate: programmatic transaction management helper.
//   Used in TenantContext to wrap DB calls with BEGIN/COMMIT/ROLLBACK.
import org.springframework.transaction.support.TransactionTemplate;

// @Configuration: marks this as a Spring configuration class.
import org.springframework.context.annotation.Configuration;

// @Bean: marks methods that produce Spring-managed beans.
import org.springframework.context.annotation.Bean;

@Configuration
public class DataSourceConfig {

    /**
     * Creates a NamedParameterJdbcTemplate bean.
     *
     * This is the primary tool used by all Repository classes to
     * execute SQL against the PostgreSQL database. Named parameters
     * (:param) are safer and more readable than positional ? markers.
     *
     * Spring Boot's auto-configured HikariCP DataSource is injected
     * automatically as a parameter.
     *
     * @param dataSource The HikariCP connection pool (auto-configured by Spring Boot).
     * @return           A NamedParameterJdbcTemplate wrapping the data source.
     */
    @Bean
    public NamedParameterJdbcTemplate namedParameterJdbcTemplate(DataSource dataSource) {
        return new NamedParameterJdbcTemplate(dataSource);
    }

    /**
     * Creates a TransactionTemplate bean for programmatic transaction management.
     *
     * Used exclusively by TenantContext.withOwner() to:
     *   1. Open a database transaction (BEGIN)
     *   2. Execute SET LOCAL app.current_owner_id = '<uuid>'
     *   3. Run the repository query
     *   4. Commit on success (COMMIT) or roll back on error (ROLLBACK)
     *
     * This pattern is required because SET LOCAL only persists for
     * the duration of the current transaction — it must be in the
     * same transaction as the query it is meant to scope.
     *
     * @param transactionManager The Spring-managed JDBC transaction manager.
     * @return                   A TransactionTemplate instance.
     */
    @Bean
    public TransactionTemplate transactionTemplate(
            PlatformTransactionManager transactionManager) {
        return new TransactionTemplate(transactionManager);
    }
}
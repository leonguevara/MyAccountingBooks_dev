// ============================================================
// PayeeService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic for payee operations.
//          Resolves ownerID from JWT and delegates to repository.
// ============================================================
// Last edited: 2026-04-02
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.request.CreatePayeeRequest;
import com.leonguevara.mab.mab_api.dto.response.PayeeResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.PayeeRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/**
 * Service layer for payee operations.
 *
 * <p>Resolves the authenticated owner's UUID from the {@link SecurityContextHolder}
 * and delegates all data access to {@link PayeeRepository}. No business logic beyond
 * ownership resolution lives here.</p>
 *
 * @see PayeeRepository
 * @see com.leonguevara.mab.mab_api.controller.PayeeController
 */
@Service
public class PayeeService {

    /** Repository handling all {@code public.payee} data access. */
    private final PayeeRepository repository;

    /**
     * Constructs the service with its required {@link PayeeRepository} dependency.
     *
     * @param repository payee data-access bean
     */
    public PayeeService(PayeeRepository repository) {
        this.repository = repository;
    }

    /**
     * Returns all active payees for the given ledger.
     *
     * <p>Delegates to {@link PayeeRepository#findByLedger} after resolving the
     * owner UUID via {@link #resolveOwnerID()}.</p>
     *
     * @param ledgerID UUID of the ledger whose payees are requested
     * @return list of {@link PayeeResponse} objects ordered by name; empty if none found
     * @throws ApiException HTTP 401 if no valid authenticated principal is present
     */
    public List<PayeeResponse> getPayeesForLedger(UUID ledgerID) {
        return repository.findByLedger(resolveOwnerID(), ledgerID);
    }

    /**
     * Creates a new payee in the ledger specified by the request body.
     *
     * <p>Delegates to {@link PayeeRepository#create} after resolving the owner UUID.
     * The repository enforces the {@code (ledger_id, name)} uniqueness constraint.</p>
     *
     * @param request validated request containing {@code ledgerId} and {@code name}
     * @return the created {@link PayeeResponse}
     * @throws ApiException HTTP 401 if no valid authenticated principal is present
     * @throws org.springframework.dao.DataIntegrityViolationException if the name already
     *         exists in the ledger (mapped to HTTP 409 by the exception handler)
     */
    public PayeeResponse createPayee(CreatePayeeRequest request) {
        return repository.create(resolveOwnerID(),
                request.ledgerId(), request.name());
    }

    /**
     * Extracts the owner UUID from the current security context.
     *
     * <p>Pattern-matches the principal against {@link UserPrincipal} using a record
     * deconstruction pattern. Throws HTTP 401 if the context is empty or the principal
     * is not a {@link UserPrincipal}.</p>
     *
     * @return the authenticated owner's UUID
     * @throws ApiException HTTP 401 if authentication is missing or the principal type is unexpected
     */
    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return ownerID;
    }
}
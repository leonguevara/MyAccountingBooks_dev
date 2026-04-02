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

@Service
public class PayeeService {

    private final PayeeRepository repository;

    public PayeeService(PayeeRepository repository) {
        this.repository = repository;
    }

    /** Returns all active payees for the given ledger. */
    public List<PayeeResponse> getPayeesForLedger(UUID ledgerID) {
        return repository.findByLedger(resolveOwnerID(), ledgerID);
    }

    /** Creates a new payee in the given ledger. */
    public PayeeResponse createPayee(CreatePayeeRequest request) {
        return repository.create(resolveOwnerID(),
                request.ledgerId(), request.name());
    }

    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return ownerID;
    }
}
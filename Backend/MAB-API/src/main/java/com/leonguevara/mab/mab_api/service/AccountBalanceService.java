// ============================================================
// AccountBalanceService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Service layer for retrieving account balances.
//          Extracts the authenticated owner from the security context
//          and delegates to AccountBalanceRepository.
// ============================================================
// Last edited: 2026-03-21
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.response.AccountBalanceResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.AccountBalanceRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class AccountBalanceService {

    private final AccountBalanceRepository repository;

    public AccountBalanceService(AccountBalanceRepository repository) {
        this.repository = repository;
    }

    /**
     * Returns balances for all accounts in the ledger.
     *
     * @param ledgerId The ledger UUID from the URL path.
     * @return         Flat list of AccountBalanceResponse.
     */
    public List<AccountBalanceResponse> getBalances(UUID ledgerId) {
        UUID ownerID = resolveOwnerID();
        return repository.findByLedger(ownerID, ledgerId);
    }

    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return ownerID;
    }
}

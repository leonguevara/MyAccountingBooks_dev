// ============================================================
// PriceService.java
// Package: com.leonguevara.mab.mab_api.service
//
// Purpose: Business logic for price CRUD operations.
//
//          Resolves ownerID from the JWT SecurityContext and
//          delegates to PriceRepository for all data access.
//
//          Validation:
//            - commodityId must not equal currencyId (a commodity
//              cannot be priced against itself).
//            - Other constraints (e.g. unique date) are enforced
//              by the database unique index.
// ============================================================
// Last edited: 2026-04-03
// Author: León Felipe Guevara Chávez
// Developed with AI assistance.
// ============================================================

package com.leonguevara.mab.mab_api.service;

import com.leonguevara.mab.mab_api.dto.request.CreatePriceRequest;
import com.leonguevara.mab.mab_api.dto.response.PriceResponse;
import com.leonguevara.mab.mab_api.exception.ApiException;
import com.leonguevara.mab.mab_api.repository.PriceRepository;
import com.leonguevara.mab.mab_api.security.UserPrincipal;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class PriceService {

    private final PriceRepository priceRepository;

    public PriceService(PriceRepository priceRepository) {
        this.priceRepository = priceRepository;
    }

    /**
     * Returns all active prices for the given ledger, ordered by date descending.
     *
     * @param  ledgerID The UUID of the ledger.
     * @return          List of {@link PriceResponse} ordered by date DESC.
     */
    public List<PriceResponse> getPricesForLedger(UUID ledgerID) {
        return priceRepository.findByLedger(resolveOwnerID(), ledgerID);
    }

    /**
     * Creates a new price entry in the given ledger.
     * <p>
     * Rejects requests where {@code commodityId == currencyId}. The database
     * unique constraint on {@code (ledger_id, commodity_id, currency_id, date)}
     * surfaces duplicate entries as HTTP 409.
     *
     * @param  ledgerID The UUID of the ledger.
     * @param  request  The validated {@link CreatePriceRequest}.
     * @return          The newly created {@link PriceResponse}.
     * @throws ApiException HTTP 400 if {@code commodityId} equals {@code currencyId}.
     * @throws ApiException HTTP 409 if a price already exists for the same commodity, currency, and date.
     */
    public PriceResponse createPrice(UUID ledgerID, CreatePriceRequest request) {
        if (request.commodityId().equals(request.currencyId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "commodityId and currencyId must be different.");
        }
        return priceRepository.create(resolveOwnerID(), ledgerID, request);
    }

    /**
     * Soft-deletes a price entry by setting {@code deleted_at = now()}.
     *
     * @param  priceID The UUID of the price entry to delete.
     * @throws ApiException HTTP 404 if not found or not owned by the authenticated owner.
     */
    public void deletePrice(UUID priceID) {
        priceRepository.softDelete(resolveOwnerID(), priceID);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private UUID resolveOwnerID() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal(UUID ownerID))) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return ownerID;
    }
}

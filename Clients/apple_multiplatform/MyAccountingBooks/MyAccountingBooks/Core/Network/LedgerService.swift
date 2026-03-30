//
//  Core/Network/LedgerService.swift
//  LedgerService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11.
//  Last modified by León Felipe Guevara Chávez on 2026-03-29.
//  Developed with AI assistance
//

import Foundation

/// A service that encapsulates network operations related to ledgers and COA templates.
///
/// `LedgerService` wraps ``APIClient`` for all ledger-related routes, providing a
/// focused API surface for the three available operations:
///
/// | Method | Route | Description |
/// |---|---|---|
/// | ``fetchLedgers(token:)`` | `GET /ledgers` | List all ledgers owned by the authenticated user |
/// | ``createLedger(_:token:)`` | `POST /ledgers` | Create a new ledger, optionally seeded from a COA template |
/// | ``fetchCoaTemplates(token:)`` | `GET /coa-templates` | Retrieve the global COA template catalog |
///
/// ## Usage
///
/// ```swift
/// let token = TokenStore.shared.load()!
/// let ledgers = try await LedgerService.shared.fetchLedgers(token: token)
///
/// let request = CreateLedgerRequest(
///     name: "Household",
///     currencyMnemonic: "USD",
///     decimalPlaces: 2,
///     coaTemplateCode: "basic",
///     coaTemplateVersion: "2024.1"
/// )
/// let created = try await LedgerService.shared.createLedger(request, token: token)
/// ```
///
/// - SeeAlso: ``APIClient``, ``LedgerResponse``, ``CreateLedgerRequest``, ``CoaTemplateItem``
final class LedgerService {

    /// Shared singleton instance for convenient access.
    static let shared = LedgerService()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    // MARK: - List Ledgers

    /// Retrieves the list of ledgers accessible to the authenticated user.
    /// - Parameter token: A bearer token used to authorize the request.
    /// - Returns: An array of ``LedgerResponse`` models.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
    ///
    /// ## Example
    /// ```swift
    /// let token = try await authService.token
    /// let ledgers = try await LedgerService.shared.fetchLedgers(token: token!)
    /// ```
    func fetchLedgers(token: String) async throws -> [LedgerResponse] {
        try await APIClient.shared.request(
            .listLedgers,
            method: "GET",
            token: token
        )
    }

    // MARK: - Create Ledger

    /// Creates a new ledger with the provided request payload.
    /// - Parameters:
    ///   - request: The payload describing the new ledger.
    ///   - token: A bearer token used to authorize the request.
    /// - Returns: The created ``LedgerResponse``.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
    ///
    /// ## Example
    /// ```swift
    /// let token = TokenStore.shared.load()!
    /// let body = CreateLedgerRequest(name: "Biz", currencyMnemonic: "USD", decimalPlaces: 2)
    /// let ledger = try await LedgerService.shared.createLedger(body, token: token)
    /// ```
    func createLedger(_ request: CreateLedgerRequest, token: String) async throws -> LedgerResponse {
        try await APIClient.shared.request(
            .createLedger,
            method: "POST",
            body: request,
            token: token
        )
    }
    
    // MARK: - COA Templates

    /// Retrieves the global chart-of-accounts template catalog.
    ///
    /// Templates are not scoped to any owner or ledger — they are shared across all tenants.
    /// Use the `code` and `version` from the returned items when creating a ledger with a
    /// pre-built chart of accounts via ``createLedger(_:token:)``.
    ///
    /// - Parameter token: A bearer token used to authorize the request.
    /// - Returns: An array of ``CoaTemplateItem`` values, ordered by name then version.
    /// - Throws: ``APIError`` for known API failures or other network-related errors.
    ///
    /// ## Example
    /// ```swift
    /// let templates = try await LedgerService.shared.fetchCoaTemplates(token: token)
    /// // Pass a template to ledger creation
    /// let request = CreateLedgerRequest(
    ///     name: "Household",
    ///     currencyMnemonic: "USD",
    ///     decimalPlaces: 2,
    ///     coaTemplateCode: templates.first?.code,
    ///     coaTemplateVersion: templates.first?.version
    /// )
    /// ```
    ///
    /// - SeeAlso: ``CoaTemplateItem``, ``createLedger(_:token:)``
    func fetchCoaTemplates(token: String) async throws -> [CoaTemplateItem] {
        try await APIClient.shared.request(
            .coaTemplates,
            method: "GET",
            token: token
        )
    }
}


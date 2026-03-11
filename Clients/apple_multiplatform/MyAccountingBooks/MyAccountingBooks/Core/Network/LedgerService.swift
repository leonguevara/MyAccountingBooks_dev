//
//  Core/Network/LedgerService.swift
//  LedgerService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-11.
//  Developed with AI assistance
//

import Foundation

/// A service that encapsulates network operations related to ledgers.
///
/// Uses `APIClient` to perform requests for listing and creating ledgers.
/// Provides a shared singleton for convenience.
///
/// Usage:
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
final class LedgerService {

    /// Shared singleton instance for convenient access.
    static let shared = LedgerService()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    // MARK: - List Ledgers

    /// Retrieves the list of ledgers accessible to the authenticated user.
    /// - Parameter token: A bearer token used to authorize the request.
    /// - Returns: An array of `LedgerResponse` models.
    /// - Throws: `APIError` for known API failures or other network-related errors.
    ///
    /// Example:
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
    /// - Returns: The created `LedgerResponse`.
    /// - Throws: `APIError` for known API failures or other network-related errors.
    ///
    /// Example:
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
}


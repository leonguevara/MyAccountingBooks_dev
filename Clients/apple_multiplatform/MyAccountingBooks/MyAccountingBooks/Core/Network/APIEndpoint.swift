//
//  Core/Network/APIEndpoint.swift
//  APIEndpoint.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-03.
//  Developed with AI assistance.
//

import Foundation

/// Typed enum of all backend API routes; the ``url`` computed property assembles the full `URL`.
///
/// Each case maps to one HTTP endpoint. Cases that require a resource identifier carry it as an
/// associated value. ``commodities(namespace:)`` appends an optional query parameter.
/// Change ``baseURL`` to target a different environment.
///
/// - Important: Always use HTTPS in non-development environments.
/// - Note: ``url`` is computed on every access; assign it to a local constant when used more than once.
/// - SeeAlso: ``APIClient``, ``APIError``
enum APIEndpoint {
    /// Root URL prepended to every endpoint path.
    ///
    /// Update this constant to target a different environment (staging, production).
    /// Always use HTTPS in non-development environments.
    static let baseURL = URL(string: "http://localhost:8080")!

    // MARK: - Auth

    /// `POST /auth/login` — verifies credentials and returns a signed JWT.
    case login

    // MARK: - Ledgers

    /// `GET /ledgers` — returns all ledgers owned by the authenticated user.
    case listLedgers

    /// `POST /ledgers` — creates a new ledger with name, currency, and decimal places.
    case createLedger

    // MARK: - Accounts

    /// `GET /ledgers/{ledgerID}/accounts` — returns a flat account list for the ledger.
    ///
    /// The flat list can be converted to a hierarchy via ``AccountTreeBuilder``.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    case accounts(ledgerID: UUID)
    
    /// `GET /ledgers/{ledgerID}/balances` — returns signed balances as rationals (`balanceNum / balanceDenom`)
    /// for every account in the ledger.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    /// - SeeAlso: ``AccountBalanceResponse``
    case balances(ledgerID: UUID)
    
    /// `POST /accounts` — creates a new account in the chart of accounts.
    ///
    /// The backend validates that the parent exists, the `accountTypeCode` is from the catalog,
    /// and that the combined properties satisfy chart-of-accounts rules.
    ///
    /// - SeeAlso: ``CreateAccountRequest``, ``accountTypes``, ``AccountRole``
    case createAccount
    
    /// `PATCH /accounts/{id}` — partially updates an account; only non-nil fields are modified.
    ///
    /// - Parameter id: The unique identifier of the account to update.
    /// - Important: Changing `accountRole` or `parentId` may violate chart-of-accounts rules;
    ///   the backend validates before applying.
    /// - SeeAlso: ``PatchAccountRequest``
    case patchAccount(id: UUID)
    
    /// `GET /account-types` — returns the global catalog of account type classifications.
    ///
    /// Each entry carries a `code` (e.g., `"BANK"`), `kind` (Asset/Liability/…),
    /// `normalBalance` direction, and a `sortOrder` for display ordering.
    ///
    /// - SeeAlso: ``AccountTypeItem``, ``CreateAccountRequest``
    case accountTypes

    // MARK: - Transactions

    /// `GET /ledgers/{ledgerID}/transactions` — returns all transactions with splits for the ledger.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    case transactions(ledgerID: UUID)

    /// `POST /transactions` — posts a new balanced transaction with its split lines.
    case postTransaction

    /// `POST /transactions/{id}/reverse` — creates a mirror transaction with DEBIT↔CREDIT swapped.
    ///
    /// The original transaction is not modified; the reversing entry references it via memo.
    ///
    /// - Parameter id: The unique identifier of the transaction to reverse.
    case reverseTransaction(id: UUID)

    /// `POST /transactions/{id}/void` — marks a transaction as voided (`is_voided = true`).
    ///
    /// No reversing entry is created; the transaction remains in the ledger flagged as void.
    ///
    /// - Parameter id: The unique identifier of the transaction to void.
    case voidTransaction(id: UUID)

    /// `PATCH /transactions/{id}` — partially updates a transaction; only non-nil fields are modified.
    ///
    /// Supports transaction-level fields (`memo`, `num`, `postDate`) and individual splits by `splitId`.
    ///
    /// - Parameter id: The unique identifier of the transaction to update.
    /// - SeeAlso: ``PatchTransactionRequest``
    case patchTransaction(id: UUID)

    /// `POST /auth/register` — creates a new owner account and returns a signed JWT immediately.
    case register

    // MARK: - Commodities

    /// `GET /commodities` — returns commodities (currencies, stocks, assets), optionally filtered by namespace.
    ///
    /// - Parameter namespace: Namespace filter (e.g., `"CURRENCY"`, `"ISO4217"`); `nil` returns all.
    case commodities(namespace: String?)
    
    // MARK: - COA Templates

    /// `GET /coa-templates` — returns all active chart-of-accounts templates from the global catalog.
    ///
    /// Templates are not tenant-scoped; they are shared across all users and require no owner context.
    /// Use the `code` and `version` fields when creating a ledger with a pre-built chart of accounts.
    ///
    /// - SeeAlso: ``CoaTemplateItem``
    case coaTemplates
    
    // MARK: - Payees
    
    /// `GET /ledgers/{ledgerID}/payees` — returns all active payees for the ledger, ordered by name.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    /// - SeeAlso: ``PayeeResponse``
    case payees(ledgerID: UUID)

    /// `POST /payees` — creates a new payee in the ledger specified by the request body.
    ///
    /// The `(ledgerId, name)` combination must be unique; a duplicate triggers HTTP 409.
    ///
    /// - SeeAlso: ``CreatePayeeRequest``, ``PayeeResponse``
    case createPayee
    
    // MARK: - Prices
    
    /// `GET /ledgers/{ledgerID}/prices` — returns all active price entries for the ledger, ordered by date descending.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    case prices(ledgerID: UUID)

    /// `POST /ledgers/{ledgerID}/prices` — records a new exchange rate entry for the ledger.
    ///
    /// - Parameter ledgerID: The unique identifier of the ledger.
    /// - SeeAlso: ``CreatePriceRequest``, ``PriceResponse``
    case createPrice(ledgerID: UUID)

    /// `DELETE /prices/{id}` — soft-deletes a price entry by setting `deleted_at = now()`.
    ///
    /// - Parameter id: The unique identifier of the price entry to delete.
    case deletePrice(id: UUID)

    // MARK: - URL Construction
    
    /// The fully-qualified URL for this endpoint, assembled from ``baseURL`` and the case's path.
    ///
    /// ``commodities(namespace:)`` appends a `namespace` query item when the parameter is non-nil.
    ///
    /// - Note: Computed on every access; assign to a local constant when used more than once.
    var url: URL {
        switch self {
        case .login:
            return Self.baseURL.appendingPathComponent("auth/login")
        case .listLedgers, .createLedger:
            return Self.baseURL.appendingPathComponent("ledgers")
        case .accounts(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/accounts")
        case .balances(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/balances")
        case .transactions(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/transactions")
        case .postTransaction:
            return Self.baseURL.appendingPathComponent("transactions")
        case .reverseTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/reverse")
        case .voidTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)/void")
        case .patchTransaction(let id):
            return Self.baseURL.appendingPathComponent("transactions/\(id)")
        case .commodities(let ns):
            var components = URLComponents(url: Self.baseURL.appendingPathComponent("commodities"), resolvingAgainstBaseURL: false)!
            if let ns { components.queryItems = [URLQueryItem(name: "namespace", value: ns)] }
            return components.url!
        case .createAccount:
            return Self.baseURL.appendingPathComponent("accounts")
        case .patchAccount(let id):
            return Self.baseURL.appendingPathComponent("accounts/\(id)")
        case .accountTypes:
            return Self.baseURL.appendingPathComponent("account-types")
        case .coaTemplates:
            return Self.baseURL.appendingPathComponent("coa-templates")
        case .register:
            return Self.baseURL.appendingPathComponent("auth/register")
        case .payees(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/payees")
        case .createPayee:
            return Self.baseURL.appendingPathComponent("payees")
        case .prices(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/prices")
        case .createPrice(let id):
            return Self.baseURL.appendingPathComponent("ledgers/\(id)/prices")
        case .deletePrice(let id):
            return Self.baseURL.appendingPathComponent("prices/\(id)")
        }
    }
}

//
//  Core/Network/APIEndpoint.swift
//  APIEndpoint.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Last modified by León Felipe Guevara Chávez on 2026-04-02.
//  Developed with AI assistance.
//

import Foundation

/// Describes all backend API endpoints and constructs concrete `URL` values for requests.
///
/// `APIEndpoint` centralizes the path logic for all backend routes, providing a single
/// source of truth for building request URLs. All endpoints are built from the shared
/// ``baseURL``, which can be changed to target different environments.
///
/// ## Features
///
/// - **Type-safe endpoints**: Each route is an enum case — no raw strings scattered across the codebase.
/// - **Associated values**: Endpoints requiring IDs carry them as labeled parameters.
/// - **URL construction**: The ``url`` computed property assembles the full URL.
/// - **Query parameters**: Endpoints such as ``commodities(namespace:)`` support optional query strings.
/// - **Environment switching**: Update ``baseURL`` to point to staging or production.
///
/// ## Available Endpoints
///
/// | Group | Case | Method | Path |
/// |---|---|---|---|
/// | Auth | ``login`` | POST | `/auth/login` |
/// | Auth | ``register`` | POST | `/auth/register` |
/// | Ledgers | ``listLedgers`` | GET | `/ledgers` |
/// | Ledgers | ``createLedger`` | POST | `/ledgers` |
/// | Accounts | ``accounts(ledgerID:)`` | GET | `/ledgers/{id}/accounts` |
/// | Accounts | ``balances(ledgerID:)`` | GET | `/ledgers/{id}/balances` |
/// | Accounts | ``createAccount`` | POST | `/accounts` |
/// | Accounts | ``patchAccount(id:)`` | PATCH | `/accounts/{id}` |
/// | Accounts | ``accountTypes`` | GET | `/account-types` |
/// | Transactions | ``transactions(ledgerID:)`` | GET | `/ledgers/{id}/transactions` |
/// | Transactions | ``postTransaction`` | POST | `/transactions` |
/// | Transactions | ``patchTransaction(id:)`` | PATCH | `/transactions/{id}` |
/// | Transactions | ``reverseTransaction(id:)`` | POST | `/transactions/{id}/reverse` |
/// | Transactions | ``voidTransaction(id:)`` | POST | `/transactions/{id}/void` |
/// | Commodities | ``commodities(namespace:)`` | GET | `/commodities` |
/// | COA Templates | ``coaTemplates`` | GET | `/coa-templates` |
///
/// ## Usage Example
///
/// ```swift
/// // Direct URL access
/// let loginURL = APIEndpoint.login.url
///
/// // With APIClient
/// let ledgers: [LedgerResponse] = try await APIClient.shared.request(
///     .listLedgers,
///     method: "GET",
///     token: authToken
/// )
///
/// // Ledger-scoped endpoint
/// let accounts: [AccountResponse] = try await APIClient.shared.request(
///     .accounts(ledgerID: ledger.id),
///     token: authToken
/// )
/// ```
///
/// - Important: Always use HTTPS in production environments for secure communication.
/// - Note: ``url`` is computed on every access; assign it to a local variable if used multiple times.
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
    
    /// Lists all payees for a ledger.
    /// **Path:** `GET /ledgers/{ledgerID}/payees`
    case payees(ledgerID: UUID)

    /// Creates a new payee.
    /// **Path:** `POST /payees`
    case createPayee

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
        }
    }
}

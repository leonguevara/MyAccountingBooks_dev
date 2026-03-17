//
//  Core/Network/PostTransactionService.swift
//  PostTransactionService.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-16.
//  Developed with AI assistance.
//

import Foundation

/**
 Service layer for posting transaction data to the backend.
 
 This service encapsulates the POST /transactions API call, providing a simple interface
 to send transaction data to the backend and receive a response.
 
 # Overview
 The `PostTransactionService` is a singleton that handles the creation of new transactions
 by communicating with the backend API. It accepts a `PostTransactionRequest` containing
 all transaction details (including splits) and returns a `TransactionResponse` upon success.
 
 # Usage Example
 ```swift
 let service = PostTransactionService.shared
 let request = PostTransactionRequest(
     ledgerId: ledgerId,
     currencyCommodityId: currencyId,
     postDate: Date(),
     enterDate: nil,
     memo: "Office supplies",
     num: "TX001",
     status: 0,
     payeeId: payeeId,
     splits: [split1, split2]
 )
 
 do {
     let response = try await service.post(request, token: authToken)
     print("Transaction created with ID: \(response.id)")
 } catch {
     print("Failed to create transaction: \(error)")
 }
 ```
 
 - Note: This service uses Swift Concurrency (async/await) for network operations.
 - SeeAlso: `PostTransactionRequest`, `TransactionResponse`, `APIClient`
 */
 
/// A singleton network service to handle posting transactions to the backend.
final class PostTransactionService {

    /// The shared singleton instance of `PostTransactionService`.
    static let shared = PostTransactionService()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    /**
     Sends a POST request to create a new transaction on the backend.
     
     This method constructs and sends a POST request to the `/transactions` endpoint,
     including the transaction details and all associated splits. The request must
     be authenticated with a valid authorization token.

     - Parameters:
       - request: The `PostTransactionRequest` containing the complete transaction details,
                  including ledger ID, currency, dates, memo, status, and all split lines.
                  The splits must balance (total debits equal total credits).
       - token: A string authorization token used for authentication with the backend API.

     - Throws: An error if:
         - The network request fails (no connectivity, timeout, etc.)
         - The server returns an error response (invalid data, unauthorized, etc.)
         - The response cannot be decoded into a `TransactionResponse`

     - Returns: A `TransactionResponse` representing the server's response to the posted transaction,
                typically including the newly created transaction ID and confirmation details.
     
     # Example
     ```swift
     let request = PostTransactionRequest(
         ledgerId: myLedgerId,
         currencyCommodityId: usdId,
         postDate: Date(),
         enterDate: Date(),
         memo: "Monthly rent payment",
         num: "CH-1234",
         status: 1,
         payeeId: landlordId,
         splits: [rentExpenseSplit, bankAccountSplit]
     )
     
     let response = try await PostTransactionService.shared.post(request, token: userToken)
     print("Created transaction: \(response.id)")
     ```
     */
    func post(
        _ request: PostTransactionRequest,
        token: String
    ) async throws -> TransactionResponse {
        try await APIClient.shared.request(
            .postTransaction,
            method: "POST",
            body: request,
            token: token
        )
    }
}

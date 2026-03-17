//
//  Core/Network/APIClient.swift
//  APIClient.swift
//  MyAccountingBooks
//
//  Created by León Felipe Guevara Chávez on 2026-03-10.
//  Developed with AI assistance.
//

import Foundation

/**
 A lightweight HTTP client for interacting with the backend API.

 `APIClient` centralizes common request setup including decoding strategies,
 headers, and authentication token handling, and returns decoded models from the server.
 
 # Features
 - Singleton pattern for consistent configuration across the app
 - Automatic JSON encoding/decoding with ISO8601 date formatting
 - Bearer token authentication support
 - Comprehensive error mapping (401, 404, 5xx, decoding errors)
 - Generic request interface supporting any `Decodable` response type
 - Swift Concurrency (async/await) support

 # Usage Examples
 
 **Fetching data:**
 ```swift
 struct Ledger: Decodable { 
     let id: UUID
     let name: String 
 }

 // Simple GET request
 let ledgers: [Ledger] = try await APIClient.shared.request(.listLedgers)
 ```
 
 **Creating resources with POST:**
 ```swift
 struct CreateLedgerBody: Encodable { 
     let name: String 
 }
 
 let created: Ledger = try await APIClient.shared.request(
     .createLedger,
     method: "POST",
     body: CreateLedgerBody(name: "Household"),
     token: myAuthToken
 )
 ```

 # Error Handling
 
 The client provides structured error handling through the `APIError` type:
 
 ```swift
 do {
     let accounts: [Account] = try await APIClient.shared.request(
         .accounts(ledgerID: id),
         token: authToken
     )
     // Handle success
 } catch let apiError as APIError {
     // Handle specific API errors
     switch apiError {
     case .unauthorized:
         print("Authentication required")
     case .notFound:
         print("Resource not found")
     case .serverError(let code):
         print("Server error: \(code)")
     case .decodingError(let error):
         print("Failed to decode response: \(error)")
     case .unknown(let error):
         print("Unknown error: \(error)")
     }
 } catch {
     // Handle other errors (network, etc.)
     print(error.localizedDescription)
 }
 ```
 
 # JSON Encoding/Decoding
 
 The client uses **camelCase** for all JSON keys (matching Swift naming conventions).
 Dates are encoded/decoded using the ISO8601 format.
 
 To ensure proper encoding/decoding, use explicit `CodingKeys` in your models:
 
 ```swift
 struct PostTransactionRequest: Encodable {
     let ledgerId: UUID
     let currencyCommodityId: UUID
     
     enum CodingKeys: String, CodingKey {
         case ledgerId
         case currencyCommodityId
     }
 }
 ```
 
 - Important: The backend API must accept and return camelCase JSON keys.
 - Note: Snake_case conversion has been removed. All keys use camelCase.
 - SeeAlso: `APIEndpoint`, `APIError`
 */
final class APIClient {
    
    // MARK: - Properties
    
    /// Shared singleton instance providing consistent API client configuration throughout the app.
    static let shared = APIClient()
    
    /// The underlying URLSession used to perform all network requests.
    ///
    /// Uses the shared session with default configuration. For custom configurations
    /// (timeouts, caching policies, etc.), this could be modified to use a custom session.
    private let session = URLSession.shared
    
    /// JSON decoder configured with ISO8601 date decoding strategy.
    ///
    /// This decoder is reused for all API responses to ensure consistent decoding behavior.
    /// Keys are expected to be in camelCase format matching Swift conventions.
    private let decoder = JSONDecoder()

    // MARK: - Initialization
    
    /// Initializes the API client with default JSON decoding configuration.
    ///
    /// The decoder is configured with:
    /// - ISO8601 date decoding strategy for automatic Date parsing
    /// - CamelCase key decoding (no conversion from snake_case)
    ///
    /// - Note: This initializer is private to enforce singleton usage via `APIClient.shared`.
    private init() {
        // Keys are expected in camelCase format
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Request Method
    
    /**
     Performs an HTTP request to the specified endpoint and decodes the response into type `T`.

     This method handles the complete request lifecycle:
     1. Constructs the URLRequest with appropriate headers and authentication
     2. Encodes the request body (if provided) as JSON with ISO8601 dates
     3. Executes the network request asynchronously
     4. Validates the HTTP response status code
     5. Decodes the response data into the specified type `T`

     - Parameters:
       - endpoint: The `APIEndpoint` describing the route and URL to call.
       - method: The HTTP method string (e.g., `"GET"`, `"POST"`, `"PUT"`, `"DELETE"`). Defaults to `"GET"`.
       - body: An optional `Encodable` object to be JSON-encoded and sent as the request body.
                If provided, it will be encoded with camelCase keys and ISO8601 date formatting.
       - token: An optional bearer authentication token added to the `Authorization` header.
                Required for authenticated endpoints.
                
     - Returns: A decoded instance of type `T` parsed from the successful response body.
     
     - Throws: `APIError` for known API failures:
         - `.unauthorized` (401): Invalid or missing authentication credentials
         - `.notFound` (404): The requested resource does not exist
         - `.serverError(code)`: Server-side error with the specific HTTP status code (4xx or 5xx)
         - `.decodingError(error)`: Failed to decode the response into type `T` (includes underlying error)
         - `.unknown(error)`: Other errors such as network failures, invalid URLs, etc.

     # Usage Examples
     
     **Simple GET request:**
     ```swift
     struct Ledger: Decodable { 
         let id: UUID
         let name: String 
     }
     let ledgers: [Ledger] = try await APIClient.shared.request(.listLedgers)
     ```
     
     **POST request with body and authentication:**
     ```swift
     struct CreateTransactionBody: Encodable {
         let ledgerId: UUID
         let postDate: Date
         let memo: String?
     }
     
     let body = CreateTransactionBody(
         ledgerId: ledger.id,
         postDate: Date(),
         memo: "Office supplies"
     )
     
     let transaction: Transaction = try await APIClient.shared.request(
         .postTransaction,
         method: "POST",
         body: body,
         token: authToken
     )
     ```
     
     **Error handling:**
     ```swift
     do {
         let accounts: [Account] = try await APIClient.shared.request(
             .accounts(ledgerID: id),
             token: token
         )
         print("Loaded \(accounts.count) accounts")
     } catch APIError.unauthorized {
         // Prompt user to sign in again
         showLoginScreen()
     } catch APIError.notFound {
         // Resource doesn't exist
         showErrorAlert("Account not found")
     } catch APIError.decodingError(let error) {
         // Response format issue
         print("Failed to decode: \(error)")
     } catch {
         // Network or other errors
         print("Request failed: \(error.localizedDescription)")
     }
     ```

     # HTTP Status Code Mapping
     
     - **2xx (Success)**: Response data is decoded into type `T`
     - **401 (Unauthorized)**: Throws `.unauthorized` - authentication required or failed
     - **404 (Not Found)**: Throws `.notFound` - resource doesn't exist
     - **Other 4xx/5xx**: Throws `.serverError(code)` - client or server error with status code
     
     # JSON Encoding/Decoding
     
     - **Request body**: Encoded with camelCase keys and ISO8601 dates
     - **Response body**: Decoded expecting camelCase keys and ISO8601 dates
     - **Content-Type**: Always set to `"application/json"`
     
     Decoding failures on successful responses (2xx) throw `.decodingError` to help diagnose
     API contract mismatches.
     
     - Important: All models must use explicit `CodingKeys` to ensure camelCase JSON keys.
     - Note: This method uses Swift Concurrency and must be called from an async context.
     */
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        method: String = "GET",
        body: Encodable? = nil,
        token: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            // Keys are encoded in camelCase format (no conversion to snake_case)
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:  throw APIError.serverError(http.statusCode)
        }
    }
}


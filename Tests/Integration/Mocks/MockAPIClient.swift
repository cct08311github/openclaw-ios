import Foundation
@testable import OpenClawMonitor

final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    /// Return raw JSON Data that will be decoded to the caller's expected type
    var requestDataHandler: ((Endpoint) async throws -> Data)?
    var requestVoidHandler: ((Endpoint) async throws -> Void)?
    var requestCallCount = 0
    var lastEndpoint: Endpoint?

    /// Legacy: return a pre-decoded Any (only works when T matches exactly)
    var requestHandler: ((Endpoint) async throws -> Any)?

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestCallCount += 1
        lastEndpoint = endpoint

        // Prefer data handler — encodes/decodes correctly for private inner types
        if let dataHandler = requestDataHandler {
            let data = try await dataHandler(endpoint)
            return try JSONDecoder().decode(T.self, from: data)
        }

        // Fallback to Any handler
        guard let handler = requestHandler else {
            throw AppError.serverError("MockAPIClient: no handler configured")
        }
        guard let result = try await handler(endpoint) as? T else {
            throw AppError.decoding(NSError(domain: "MockAPIClient", code: -1))
        }
        return result
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        requestCallCount += 1
        lastEndpoint = endpoint
        if let handler = requestVoidHandler {
            try await handler(endpoint)
        }
    }
}

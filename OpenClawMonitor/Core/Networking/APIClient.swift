import Foundation

protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func requestVoid(_ endpoint: Endpoint) async throws
}

@Observable
final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let maxRetries = 3
    private var tokenProvider: (@Sendable () -> String?)?

    init(baseURL: URL) {
        self.baseURL = baseURL

        // Trust self-signed certs for Tailscale/mkcert
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config, delegate: TrustAllDelegate(), delegateQueue: nil)
    }

    func setTokenProvider(_ provider: @escaping @Sendable () -> String?) {
        self.tokenProvider = provider
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await executeWithRetry(endpoint)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.decoding(error)
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        _ = try await executeWithRetry(endpoint)
    }

    // MARK: - Private

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw AppError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData = endpoint.bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        return request
    }

    private func executeWithRetry(_ endpoint: Endpoint, attempt: Int = 0) async throws -> Data {
        do {
            let request = try buildRequest(endpoint)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.network(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 401 {
                throw AppError.unauthorized
            }

            if httpResponse.statusCode >= 400 {
                let errorBody = try? JSONDecoder().decode(SimpleResponse.self, from: data)
                throw AppError.serverError(errorBody?.error ?? "HTTP \(httpResponse.statusCode)")
            }

            return data
        } catch let error as AppError where error.isRetryable {
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(for: .seconds(delay))
                return try await executeWithRetry(endpoint, attempt: attempt + 1)
            }
            throw error
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            if attempt < maxRetries && error.isRetryable {
                let delay = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(for: .seconds(delay))
                return try await executeWithRetry(endpoint, attempt: attempt + 1)
            }
            throw AppError.network(error)
        } catch {
            throw AppError.unknown(error)
        }
    }
}

// MARK: - Helpers

private extension AppError {
    var isRetryable: Bool {
        switch self {
        case .network: true
        case .serverError: true
        case .unauthorized, .decoding, .sseDisconnected, .unknown: false
        }
    }
}

private extension URLError {
    var isRetryable: Bool {
        [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost].contains(code)
    }
}

// MARK: - SSL Trust Delegate (for mkcert / self-signed certs)

private final class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }
}

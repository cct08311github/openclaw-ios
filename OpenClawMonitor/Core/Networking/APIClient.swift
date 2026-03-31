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

        // Trust self-signed certs for Tailscale/mkcert (DEBUG only)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpShouldSetCookies = false
        #if DEBUG
        self.session = URLSession(configuration: config, delegate: TrustAllDelegate(), delegateQueue: nil)
        #else
        self.session = URLSession(configuration: config, delegate: ProductionSecurityDelegate(), delegateQueue: nil)
        #endif
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
            appLog(.debug, .network, "\(endpoint.method.rawValue) \(endpoint.path)")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.network(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 401 {
                appLog(.warning, .network, "401 Unauthorized: \(endpoint.path)")
                throw AppError.unauthorized
            }

            if httpResponse.statusCode >= 400 {
                let errorBody = try? JSONDecoder().decode(SimpleResponse.self, from: data)
                appLog(.error, .network, "HTTP \(httpResponse.statusCode): \(endpoint.path) — \(errorBody?.error ?? "unknown")")
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

// MARK: - SSL Trust Delegate
// DEBUG: accepts self-signed certs for localhost/mkcert/Tailscale dev environments
// RELEASE: delegates to system default CA validation (no custom trust)

// In production, implement Certificate Pinning by overriding:
//   1. Extract server certificate public key
//   2. Compare against pinned hash
//   3. Reject if mismatch
#if DEBUG
private final class TrustAllDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        let host = challenge.protectionSpace.host
        if isDevelopmentHost(host) {
            return (.useCredential, URLCredential(trust: serverTrust))
        }
        return (.performDefaultHandling, nil)
    }

    private func isDevelopmentHost(_ host: String) -> Bool {
        let developmentHosts = ["localhost", "127.0.0.1", "100.94.135.81"]
        return developmentHosts.contains(host) || host.hasSuffix(".local")
    }
}
#endif

// MARK: - Production Security Delegate (RELEASE only)

/// Certificate pinning delegate for production builds.
/// Loads pinned public key hashes from CertificatePins.plist bundle config.
/// If no pins are configured for a host, delegates to system CA validation (failsafe).
#if !DEBUG
private final class ProductionSecurityDelegate: NSObject, URLSessionDelegate {
    /// SHA-256 SPKI hashes keyed by hostname. Configured in CertificatePins.plist.
    /// Format: "hostname" -> "sha256/Base64EncodedHash=="
    private let pinnedHosts: [String: Set<String>]

    override init() {
        // Load pins from bundle config (CertificatePins.plist)
        // Each entry: hostname -> Set of accepted sha256/...== hashes
        var hosts: [String: Set<String>] = [:]
        if let url = Bundle.main.url(forResource: "CertificatePins", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String]] {
            for (host, hashes) in plist {
                hosts[host] = Set(hashes)
            }
        }
        self.pinnedHosts = hosts
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        let host = challenge.protectionSpace.host

        // If no pins configured for this host, fall back to system validation (failsafe)
        guard let pins = pinnedHosts[host], !pins.isEmpty else {
            // No pins configured — delegate to system CA store
            return (.performDefaultHandling, nil)
        }

        // Verify certificate chain and extract leaf public key hash
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            appLog(.error, .network, "Certificate chain invalid for \(host): \(String(describing: error))")
            return (.cancelAuthenticationChallenge, nil)
        }

        // Get the leaf certificate's public key hash
        guard let leafCert = SecTrustGetCertificateAtIndex(serverTrust, 0),
              let leafKey = SecCertificateCopyKey(leafCert),
              let leafKeyData = SecKeyCopyExternalRepresentation(leafKey, nil) as Data? else {
            appLog(.error, .network, "Could not extract public key from certificate for \(host)")
            return (.cancelAuthenticationChallenge, nil)
        }

        // SHA-256 hash of the public key data
        let leafHash = "sha256/" + leafKeyData.base64EncodedString()
        if pins.contains(leafHash) {
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        // Pin mismatch — reject
        appLog(.error, .network, "Certificate pin mismatch for \(host): got \(leafHash), expected one of \(pins)")
        return (.cancelAuthenticationChallenge, nil)
    }
}
#endif

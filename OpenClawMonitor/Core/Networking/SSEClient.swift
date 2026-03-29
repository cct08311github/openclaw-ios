import Foundation

enum SSEConnectionState: Sendable {
    case disconnected, connecting, connected
}

struct SSEEvent: Sendable {
    let event: String?   // named event type (nil = default "message")
    let data: String
}

/// Lightweight Server-Sent Events client using URLSession bytes streaming.
/// Supports Bearer token auth, automatic reconnection with exponential backoff,
/// and heartbeat timeout detection.
actor SSEClient {
    private let baseURL: URL
    private let tokenProvider: @Sendable () -> String?
    private var task: Task<Void, Never>?
    private var urlSessionTask: URLSessionDataTask?

    private(set) var state: SSEConnectionState = .disconnected

    private let maxBackoff: TimeInterval = 60
    private let heartbeatTimeout: TimeInterval = 35  // backend sends heartbeat every 20s

    init(baseURL: URL, tokenProvider: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    /// Connect to an SSE endpoint and yield events as an AsyncStream.
    func connect(endpoint: Endpoint) -> AsyncStream<SSEEvent> {
        // Cancel any existing connection
        disconnect()

        return AsyncStream<SSEEvent> { (continuation: AsyncStream<SSEEvent>.Continuation) in
            task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                var backoff: TimeInterval = 1

                while !Task.isCancelled {
                    await self.setState(.connecting)
                    appLog(AppLogLevel.info, LogCategory.sse, "Connecting to \(endpoint.path) (attempt \(Int(backoff))s backoff)")

                    do {
                        let url = self.baseURL.appendingPathComponent(endpoint.path)
                        var request = URLRequest(url: url)
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                        if let token = self.tokenProvider() {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }

                        let config = URLSessionConfiguration.default
                        config.timeoutIntervalForRequest = self.heartbeatTimeout
                        config.httpShouldSetCookies = false
                        let session = URLSession(configuration: config, delegate: SSETrustDelegate(), delegateQueue: nil)

                        let (bytes, response) = try await session.bytes(for: request)

                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw AppError.network(URLError(.badServerResponse))
                        }

                        if httpResponse.statusCode == 401 {
                            appLog(AppLogLevel.error, LogCategory.sse, "SSE 401 Unauthorized: \(endpoint.path)")
                            continuation.finish()
                            await self.setState(.disconnected)
                            return  // Don't retry on auth failure
                        }

                        guard httpResponse.statusCode == 200 else {
                            throw AppError.serverError("SSE HTTP \(httpResponse.statusCode)")
                        }

                        await self.setState(.connected)
                        appLog(AppLogLevel.info, LogCategory.sse, "Connected to \(endpoint.path)")
                        backoff = 1

                        // Parse SSE stream
                        var eventType: String? = nil
                        var dataBuffer = ""

                        for try await line in bytes.lines {
                            if Task.isCancelled { break }

                            if line.isEmpty {
                                // Empty line = end of event
                                if !dataBuffer.isEmpty {
                                    let event = SSEEvent(event: eventType, data: dataBuffer)
                                    continuation.yield(event)
                                    eventType = nil
                                    dataBuffer = ""
                                }
                            } else if line.hasPrefix("data: ") {
                                let value = String(line.dropFirst(6))
                                if !dataBuffer.isEmpty { dataBuffer += "\n" }
                                dataBuffer += value
                            } else if line.hasPrefix("data:") {
                                let value = String(line.dropFirst(5))
                                if !dataBuffer.isEmpty { dataBuffer += "\n" }
                                dataBuffer += value
                            } else if line.hasPrefix("event: ") {
                                eventType = String(line.dropFirst(7))
                            } else if line.hasPrefix(":") {
                                // Comment line (heartbeat) — just keep connection alive
                                continue
                            }
                        }
                    } catch is CancellationError {
                        break
                    } catch {
                        // Connection failed or dropped
                    }

                    await self.setState(.disconnected)

                    if Task.isCancelled { break }

                    // Exponential backoff before reconnect
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff = min(backoff * 2, self.maxBackoff)
                }

                continuation.finish()
                await self.setState(.disconnected)
            }

            continuation.onTermination = { _ in
                Task { [weak self] in
                    await self?.disconnect()
                }
            }
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
        state = .disconnected
    }

    private func setState(_ newState: SSEConnectionState) {
        state = newState
    }
}

// SSL trust delegate for SSE connections (mkcert / Tailscale)
private final class SSETrustDelegate: NSObject, URLSessionDelegate {
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

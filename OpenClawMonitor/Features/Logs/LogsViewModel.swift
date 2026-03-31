import Foundation

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: String?
    let level: LogLevel
}

enum LogLevel {
    case normal, warning, error

    init(from text: String) {
        let lower = text.lowercased()
        if lower.contains("error") || lower.contains("fatal") || lower.contains("exception") {
            self = .error
        } else if lower.contains("warn") {
            self = .warning
        } else {
            self = .normal
        }
    }
}

@Observable @MainActor
final class LogsViewModel {
    var lines: [LogLine] = []
    var sseState: SSEConnectionState = .disconnected
    var searchText = ""
    var errorOnly = false

    private let sseClient: any SSEClientProtocol
    private var sseTask: Task<Void, Never>?
    private var onUnauthorized: (() -> Void)?
    private static let maxLines = 500

    var filteredLines: [LogLine] {
        var result = lines
        if errorOnly {
            result = result.filter { $0.level == .error }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    init(sseClient: any SSEClientProtocol, onUnauthorized: (() -> Void)? = nil) {
        self.sseClient = sseClient
        self.onUnauthorized = onUnauthorized
    }

    func startStreaming() {
        sseTask?.cancel()
        sseTask = Task {
            let stream = await sseClient.connect(endpoint: .logsStream)
            for await event in stream {
                await updateSSEState()
                if event.event == "unauthorized" {
                    self.onUnauthorized?()
                    continue
                }
                parseLogEvent(event.data)
            }
            sseState = .disconnected
        }
    }

    func stopStreaming() {
        sseTask?.cancel()
        sseTask = nil
        Task { await sseClient.disconnect() }
    }

    func clear() {
        lines.removeAll()
    }

    private func parseLogEvent(_ data: String) {
        // Backend sends: { "line": "...", "ts": "..." }
        struct LogEvent: Decodable {
            let line: String?
            let ts: String?
        }

        if let jsonData = data.data(using: .utf8),
           let event = try? JSONDecoder().decode(LogEvent.self, from: jsonData),
           let text = event.line {
            appendLine(text: text, ts: event.ts)
        } else if !data.isEmpty {
            // Raw text fallback
            appendLine(text: data, ts: nil)
        }
    }

    private func appendLine(text: String, ts: String?) {
        let line = LogLine(text: text, timestamp: ts, level: LogLevel(from: text))
        lines.append(line)
        if lines.count > Self.maxLines {
            lines.removeFirst(lines.count - Self.maxLines)
        }
    }

    private func updateSSEState() async {
        sseState = await sseClient.getState()
    }
}

import Foundation
import os.log

enum AppLogLevel: String, CaseIterable, Sendable, Comparable {
    case debug, info, warning, error

    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        }
    }

    static func < (lhs: AppLogLevel, rhs: AppLogLevel) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

enum LogCategory: String, CaseIterable, Sendable {
    case network, sse, auth, ui, system
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: AppLogLevel
    let category: LogCategory
    let message: String
}

/// Thread-safe, ring-buffered logger that writes to both os.Logger and an in-memory store.
actor AppLogger {
    static let shared = AppLogger()

    private let maxEntries = 1000
    private var entries: [LogEntry] = []
    private let osLoggers: [LogCategory: os.Logger]

    private init() {
        var loggers = [LogCategory: os.Logger]()
        for cat in LogCategory.allCases {
            loggers[cat] = os.Logger(subsystem: "com.openclaw.monitor", category: cat.rawValue)
        }
        osLoggers = loggers
        entries.reserveCapacity(maxEntries)
    }

    func log(_ level: AppLogLevel, _ category: LogCategory, _ message: String) {
        // os.Logger output (visible in Console.app and Xcode)
        osLoggers[category]?.log(level: level.osLogType, "\(message, privacy: .public)")

        // Ring buffer
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func getEntries() -> [LogEntry] {
        entries
    }

    func getEntries(level: AppLogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        entries.filter { entry in
            (level == nil || entry.level >= level!) &&
            (category == nil || entry.category == category)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

// MARK: - Convenience global functions

func appLog(_ level: AppLogLevel, _ category: LogCategory, _ message: String) {
    Task { await AppLogger.shared.log(level, category, message) }
}

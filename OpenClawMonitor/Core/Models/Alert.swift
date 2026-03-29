import Foundation

enum AlertSeverity: String, Codable {
    case info, warn, error
}

struct OCAlert: Codable, Identifiable {
    let id: String
    let timestamp: Double?
    let severity: AlertSeverity?
    let message: String?
    let source: String?
}

import Foundation

enum AgentStatus: String, Codable {
    case activeExecuting = "active_executing"
    case activeRecent = "active_recent"
    case activeHistorical = "active_historical"
    case dormant
    case inactive
    case error

    var displayColor: String {
        switch self {
        case .activeExecuting: "green"
        case .activeRecent: "blue"
        case .activeHistorical: "cyan"
        case .dormant: "gray"
        case .inactive: "secondary"
        case .error: "red"
        }
    }
}

struct Agent: Codable, Identifiable {
    let id: String
    let name: String
    let status: AgentStatus
    let emoji: String?
    let label: String?
    let lastActivity: String?
    let model: String?
    let workspace: String?
}

struct DashboardPayload: Codable {
    let agents: [Agent]?
    let subAgents: [Agent]?
    let summary: DashboardSummary?
}

struct DashboardSummary: Codable {
    let totalAgents: Int?
    let activeAgents: Int?
    let subAgentCount: Int?
    let monthlyCostTWD: Double?
}

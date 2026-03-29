import Foundation

enum TaskStatus: String, Codable {
    case backlog, inProgress = "in_progress", blocked, done
}

enum TaskPriority: String, Codable {
    case low, medium, high
}

struct OCTask: Codable, Identifiable {
    let id: String
    let domain: String?
    let title: String?
    let status: TaskStatus?
    let priority: TaskPriority?
    let tags: String?  // JSON-stringified array in backend
    let createdAtMs: Double?
    let updatedAtMs: Double?
}

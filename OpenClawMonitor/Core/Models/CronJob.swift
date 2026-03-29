import Foundation

struct CronJob: Codable, Identifiable {
    let id: String
    let name: String?
    let enabled: Bool?
    let state: CronJobState?
    let updatedAtMs: Double?
}

struct CronJobState: Codable {
    let lastRunAtMs: Double?
    let nextRunAtMs: Double?
    let lastStatus: String?
}

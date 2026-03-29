import Foundation

struct SystemStatus: Decodable {
    let success: Bool?
    let status: String?
    let features: [String: Bool]?
    let securityLevel: String?
}

struct DependencyStatus: Decodable {
    let success: Bool?
    let dependencies: [Dependency]?
}

struct Dependency: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let status: String?
    let message: String?
}

struct AlertsResponse: Decodable {
    let success: Bool
    let alerts: [OCAlert]?
}

@Observable @MainActor
final class SystemViewModel {
    var health: SystemStatus?
    var dependencies: [Dependency] = []
    var alerts: [OCAlert] = []
    var isLoading = false
    var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let healthTask: SystemStatus = apiClient.request(.health)
        async let depsTask: DependencyStatus = apiClient.request(.dependencies)
        async let alertsTask: AlertsResponse = apiClient.request(.alertsRecent)

        do {
            let (h, d, a) = try await (healthTask, depsTask, alertsTask)
            health = h
            dependencies = d.dependencies ?? []
            alerts = a.alerts ?? []
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

import Foundation

@Observable @MainActor
final class CronViewModel {
    var jobs: [CronJob] = []
    var isLoading = false
    var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            struct CronResponse: Decodable {
                let success: Bool
                let jobs: [CronJob]?
            }
            let response: CronResponse = try await apiClient.request(.cronJobs)
            jobs = response.jobs ?? []
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle(id: String) async {
        do {
            try await apiClient.requestVoid(.cronToggle(id: id))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func run(id: String) async {
        do {
            try await apiClient.requestVoid(.cronRun(id: id))
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(id: String) async {
        do {
            try await apiClient.requestVoid(.cronDelete(id: id))
            jobs.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

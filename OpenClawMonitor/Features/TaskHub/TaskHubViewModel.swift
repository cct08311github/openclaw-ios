import Foundation

struct NewTaskBody: Encodable {
    let title: String
    let domain: String
    let priority: TaskPriority
}

@Observable @MainActor
final class TaskHubViewModel {
    var tasks: [OCTask] = []
    var domains: [String] = []
    var selectedDomain: String?
    var isLoading = false
    var error: String?

    // New task form
    var showNewTaskSheet = false
    var newTitle = ""
    var newDomain = ""
    var newPriority: TaskPriority = .medium

    private let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            struct TasksResponse: Decodable {
                let success: Bool
                let tasks: [OCTask]?
            }
            let response: TasksResponse = try await apiClient.request(.tasks(domain: selectedDomain))
            tasks = response.tasks ?? []
            let allDomains = Set(tasks.compactMap(\.domain))
            if domains.isEmpty { domains = allDomains.sorted() }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTask() async {
        guard !newTitle.isEmpty, !newDomain.isEmpty else { return }
        let body = NewTaskBody(title: newTitle, domain: newDomain, priority: newPriority)
        do {
            try await apiClient.requestVoid(.createTask(body: body))
            Haptics.success()
            newTitle = ""
            newDomain = ""
            newPriority = .medium
            showNewTaskSheet = false
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateStatus(task: OCTask, newStatus: TaskStatus) async {
        guard let domain = task.domain else { return }
        struct UpdateBody: Encodable { let status: TaskStatus }
        do {
            try await apiClient.requestVoid(.updateTask(domain: domain, id: task.id, body: UpdateBody(status: newStatus)))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTask(_ task: OCTask) async {
        guard let domain = task.domain else { return }
        do {
            try await apiClient.requestVoid(.deleteTask(domain: domain, id: task.id))
            tasks.removeAll { $0.id == task.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("TaskHubViewModel Tests")
struct TaskHubViewModelTests {
    private func tasksJSON(_ tasks: [[String: Any]] = [
        ["id": "t1", "domain": "dev", "title": "Fix bug", "status": "backlog", "priority": "medium"]
    ]) -> Data {
        let dict: [String: Any] = ["success": true, "tasks": tasks]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    @Test @MainActor func loadPopulatesTasksAndDomains() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in self.tasksJSON() }

        let vm = TaskHubViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.tasks.count == 1)
        #expect(vm.domains.contains("dev"))
        #expect(vm.error == nil)
    }

    @Test @MainActor func createTaskWithValidDataCallsAPI() async {
        let mock = MockAPIClient()
        mock.requestVoidHandler = { _ in }
        mock.requestDataHandler = { _ in self.tasksJSON() }

        let vm = TaskHubViewModel(apiClient: mock)
        vm.newTitle = "New task"
        vm.newDomain = "dev"
        vm.newPriority = .high
        await vm.createTask()
        // requestVoid (create) + request (load) = at least 2 calls
        #expect(mock.requestCallCount >= 2)
    }

    @Test @MainActor func createTaskWithEmptyTitleDoesNothing() async {
        let mock = MockAPIClient()
        let vm = TaskHubViewModel(apiClient: mock)
        vm.newTitle = ""
        vm.newDomain = "dev"
        await vm.createTask()
        #expect(mock.requestCallCount == 0)
    }

    @Test @MainActor func updateStatusCallsAPI() async {
        let mock = MockAPIClient()
        let taskJSON: [String: Any] = ["id": "t1", "domain": "dev", "title": "Fix bug", "status": "backlog", "priority": "medium"]
        mock.requestVoidHandler = { _ in }
        mock.requestDataHandler = { _ in self.tasksJSON([taskJSON]) }

        let vm = TaskHubViewModel(apiClient: mock)
        await vm.load()
        guard let task = vm.tasks.first else {
            Issue.record("No task loaded")
            return
        }
        await vm.updateStatus(task: task, newStatus: .done)
        #expect(mock.requestCallCount >= 2) // load + void update + load
    }

    @Test @MainActor func deleteTaskRemovesFromList() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in self.tasksJSON() }
        mock.requestVoidHandler = { _ in }

        let vm = TaskHubViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.tasks.count == 1)
        guard let task = vm.tasks.first else {
            Issue.record("No task loaded")
            return
        }
        await vm.deleteTask(task)
        #expect(vm.tasks.isEmpty)
    }
}

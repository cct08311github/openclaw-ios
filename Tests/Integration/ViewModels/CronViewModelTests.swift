import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("CronViewModel Tests")
struct CronViewModelTests {
    private func cronJobsJSON(_ jobs: [[String: Any]] = [["id": "job1", "name": "Test Job", "enabled": true]]) -> Data {
        let dict: [String: Any] = ["success": true, "jobs": jobs]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    @Test @MainActor func loadPopulatesJobs() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in self.cronJobsJSON() }

        let vm = CronViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.jobs.count == 1)
        #expect(vm.jobs.first?.id == "job1")
        #expect(vm.error == nil)
    }

    @Test @MainActor func toggleCallsAPIAndReloads() async {
        let mock = MockAPIClient()
        mock.requestVoidHandler = { _ in }
        mock.requestDataHandler = { _ in self.cronJobsJSON() }

        let vm = CronViewModel(apiClient: mock)
        await vm.toggle(id: "job1")
        // void toggle + load request
        #expect(mock.requestCallCount >= 2)
    }

    @Test @MainActor func deleteRemovesFromList() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in self.cronJobsJSON() }
        mock.requestVoidHandler = { _ in }

        let vm = CronViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.jobs.count == 1)
        await vm.delete(id: "job1")
        #expect(vm.jobs.isEmpty)
    }

    @Test @MainActor func apiErrorSetsError() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            throw AppError.serverError("Server down")
        }

        let vm = CronViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.error != nil)
    }
}

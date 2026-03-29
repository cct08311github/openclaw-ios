import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("SystemViewModel Tests")
struct SystemViewModelTests {
    @Test @MainActor func loadPopulatesAll() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { endpoint in
            if endpoint.path.contains("health") {
                return try! JSONSerialization.data(withJSONObject: [
                    "success": true, "status": "ok", "securityLevel": "high"
                ])
            } else if endpoint.path.contains("dependencies") {
                return try! JSONSerialization.data(withJSONObject: [
                    "success": true, "dependencies": [["name": "db", "status": "ok"]]
                ])
            } else if endpoint.path.contains("alerts") {
                return try! JSONSerialization.data(withJSONObject: [
                    "success": true, "alerts": [] as [[String: Any]]
                ])
            }
            throw AppError.serverError("Unknown endpoint")
        }

        let vm = SystemViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.health?.status == "ok")
        #expect(vm.dependencies.count == 1)
        #expect(vm.alerts.isEmpty)
        #expect(vm.error == nil)
    }

    @Test @MainActor func apiErrorSetsError() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            throw AppError.serverError("timeout")
        }

        let vm = SystemViewModel(apiClient: mock)
        await vm.load()
        #expect(vm.error != nil)
    }
}

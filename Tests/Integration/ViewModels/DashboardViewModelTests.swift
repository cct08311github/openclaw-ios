import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("DashboardViewModel Tests")
struct DashboardViewModelTests {
    private static let testCacheKey = "dashboard_payload_cache_v1"

    private func payloadJSON() -> Data {
        let json = """
        {"agents":[{"id":"main","name":"Main","status":"active_executing"}],"summary":{"totalAgents":5,"activeAgents":3,"subAgentCount":1,"monthlyCostTWD":1200.0}}
        """
        return Data(json.utf8)
    }

    @Test @MainActor func refreshPopulatesAgentsAndSummary() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { [self] _ in payloadJSON() }
        let mockSSE = MockSSEClient()

        // Clean cache first
        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
        let vm = DashboardViewModel(apiClient: mock, sseClient: mockSSE)
        await vm.refresh()
        #expect(vm.agents.count == 1)
        #expect(vm.agents.first?.id == "main")
        #expect(vm.summary?.totalAgents == 5)
        #expect(vm.error == nil)
        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
    }

    @Test @MainActor func apiErrorSetsError() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            throw AppError.serverError("timeout")
        }
        let mockSSE = MockSSEClient()

        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
        let vm = DashboardViewModel(apiClient: mock, sseClient: mockSSE)
        await vm.refresh()
        #expect(vm.error != nil)
        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
    }

    @Test @MainActor func cacheSavesToUserDefaults() async {
        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)

        let mock = MockAPIClient()
        mock.requestDataHandler = { [self] _ in payloadJSON() }
        let mockSSE = MockSSEClient()

        let vm = DashboardViewModel(apiClient: mock, sseClient: mockSSE)
        await vm.refresh()

        let cached = UserDefaults.standard.data(forKey: Self.testCacheKey)
        #expect(cached != nil)

        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
    }

    @Test @MainActor func cacheRestoresOnInit() async {
        // Pre-populate cache
        UserDefaults.standard.set(payloadJSON(), forKey: Self.testCacheKey)

        let mock = MockAPIClient()
        let mockSSE = MockSSEClient()
        let vm = DashboardViewModel(apiClient: mock, sseClient: mockSSE)

        #expect(vm.agents.count == 1)
        #expect(vm.summary?.totalAgents == 5)
        #expect(mock.requestCallCount == 0)

        UserDefaults.standard.removeObject(forKey: Self.testCacheKey)
    }
}

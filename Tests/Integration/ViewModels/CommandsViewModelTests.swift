import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("CommandsViewModel Tests")
struct CommandsViewModelTests {
    @Test @MainActor func executeSetsOutput() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            try! JSONSerialization.data(withJSONObject: [
                "success": true, "output": "gateway running"
            ])
        }

        let vm = CommandsViewModel(apiClient: mock)
        await vm.execute(command: "status")
        #expect(vm.output == "gateway running")
        #expect(vm.error == nil)
    }

    @Test @MainActor func executeFailureSetsError() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            throw AppError.serverError("Command failed")
        }

        let vm = CommandsViewModel(apiClient: mock)
        await vm.execute(command: "bad-command")
        #expect(vm.error != nil)
    }

    @Test @MainActor func sendChatAppendsToHistory() async {
        let mock = MockAPIClient()
        mock.requestDataHandler = { _ in
            try! JSONSerialization.data(withJSONObject: [
                "success": true, "output": "Hello from agent"
            ])
        }

        let vm = CommandsViewModel(apiClient: mock)
        vm.selectedAgent = "main"
        vm.chatMessage = "Hello"
        await vm.sendChat()

        #expect(vm.chatHistory.count >= 2) // user + assistant
        #expect(vm.chatHistory.first?.role == "user")
        #expect(vm.chatHistory.first?.text == "Hello")
    }

    @Test @MainActor func sendChatWhenIsExecutingIsGuarded() async {
        let mock = MockAPIClient()
        let vm = CommandsViewModel(apiClient: mock)
        vm.selectedAgent = "main"
        vm.chatMessage = "test"
        vm.isExecuting = true
        await vm.sendChat()
        // Should not have sent since isExecuting is true
        #expect(mock.requestCallCount == 0)
    }
}

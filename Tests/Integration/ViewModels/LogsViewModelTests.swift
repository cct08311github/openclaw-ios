import Testing
import Foundation
@testable import OpenClawMonitor

@Suite("LogsViewModel Tests")
struct LogsViewModelTests {
    @Test @MainActor func parseLogEventAddsLine() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)
        // Directly test the parsing by simulating what startStreaming does internally
        // We'll call the internal behavior by appending a line manually
        // Since parseLogEvent is private, we test via the public interface

        // Start streaming and yield an event
        vm.startStreaming()
        // Give time for the stream to connect
        try? await Task.sleep(for: .milliseconds(100))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"test log line","ts":"2024-01-01"}"#))
        try? await Task.sleep(for: .milliseconds(100))

        #expect(vm.lines.count >= 1)
        vm.stopStreaming()
    }

    @Test @MainActor func errorLineDetectedByLevel() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)

        vm.startStreaming()
        try? await Task.sleep(for: .milliseconds(100))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"fatal error occurred","ts":"2024-01-01"}"#))
        try? await Task.sleep(for: .milliseconds(100))

        let errorLines = vm.lines.filter { $0.level == .error }
        #expect(errorLines.count >= 1)
        vm.stopStreaming()
    }

    @Test @MainActor func lineLimit500Enforced() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)

        vm.startStreaming()
        try? await Task.sleep(for: .milliseconds(100))

        for i in 0..<510 {
            await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"line \#(i)"}"#))
        }
        try? await Task.sleep(for: .milliseconds(200))

        #expect(vm.lines.count <= 500)
        vm.stopStreaming()
    }

    @Test @MainActor func errorOnlyFilterWorks() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)

        vm.startStreaming()
        try? await Task.sleep(for: .milliseconds(100))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"normal log"}"#))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"error happened"}"#))
        try? await Task.sleep(for: .milliseconds(100))

        vm.errorOnly = true
        let filtered = vm.filteredLines
        #expect(filtered.allSatisfy { $0.level == .error })
        vm.stopStreaming()
    }

    @Test @MainActor func searchTextFilterWorks() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)

        vm.startStreaming()
        try? await Task.sleep(for: .milliseconds(100))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"alpha message"}"#))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"beta message"}"#))
        try? await Task.sleep(for: .milliseconds(100))

        vm.searchText = "alpha"
        let filtered = vm.filteredLines
        #expect(filtered.allSatisfy { $0.text.contains("alpha") })
        vm.stopStreaming()
    }

    @Test @MainActor func clearEmptiesLines() async {
        let mockSSE = MockSSEClient()
        let vm = LogsViewModel(sseClient: mockSSE)

        vm.startStreaming()
        try? await Task.sleep(for: .milliseconds(100))
        await mockSSE.yield(SSEEvent(event: nil, data: #"{"line":"some log"}"#))
        try? await Task.sleep(for: .milliseconds(100))

        vm.clear()
        #expect(vm.lines.isEmpty)
        vm.stopStreaming()
    }
}

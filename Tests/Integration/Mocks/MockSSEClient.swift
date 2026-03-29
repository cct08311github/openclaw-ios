import Foundation
import os
@testable import OpenClawMonitor

final class MockSSEClient: SSEClientProtocol, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    private struct Storage {
        var state: SSEConnectionState = .disconnected
        var continuation: AsyncStream<SSEEvent>.Continuation?
    }

    func getState() async -> SSEConnectionState {
        storage.withLock { $0.state }
    }

    func connect(endpoint: Endpoint) async -> AsyncStream<SSEEvent> {
        storage.withLock { $0.state = .connected }

        return AsyncStream { [weak self] continuation in
            self?.storage.withLock { $0.continuation = continuation }
        }
    }

    func yield(_ event: SSEEvent) {
        let cont = storage.withLock { $0.continuation }
        cont?.yield(event)
    }

    func finish() {
        storage.withLock {
            $0.continuation?.finish()
            $0.state = .disconnected
        }
    }

    func disconnect() async {
        storage.withLock {
            $0.continuation?.finish()
            $0.continuation = nil
            $0.state = .disconnected
        }
    }
}

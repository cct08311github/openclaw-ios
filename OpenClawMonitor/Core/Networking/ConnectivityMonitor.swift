import Foundation
import Network

@Observable
final class ConnectivityMonitor: @unchecked Sendable {
    var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectivity-monitor")

    /// Callbacks fired when network transitions from disconnected → connected
    var onReconnect: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? true
            let nowConnected = path.status == .satisfied

            DispatchQueue.main.async {
                self?.isConnected = nowConnected
            }

            if !wasConnected && nowConnected {
                self?.onReconnect?()
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

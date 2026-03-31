import Foundation
import SwiftUI

@Observable @MainActor
final class DashboardViewModel {
    var agents: [Agent] = []
    var summary: DashboardSummary?
    var sseState: SSEConnectionState = .disconnected
    var error: String?

    private let apiClient: any APIClientProtocol
    private let sseClient: any SSEClientProtocol
    private var sseTask: Task<Void, Never>?
    private var onUnauthorized: (() -> Void)?

    private static let cacheKey = "dashboard_payload_cache_v1"

    init(apiClient: any APIClientProtocol, sseClient: any SSEClientProtocol, onUnauthorized: (() -> Void)? = nil) {
        self.apiClient = apiClient
        self.sseClient = sseClient
        self.onUnauthorized = onUnauthorized
        restoreFromCache()
    }

    func startStreaming() {
        sseTask?.cancel()
        sseTask = Task {
            let stream = await sseClient.connect(endpoint: .dashboardStream)
            for await event in stream {
                await updateSSEState()
                if event.event == "unauthorized" {
                    self.onUnauthorized?()
                    continue
                }
                guard event.event == nil || event.event == "message" else { continue }
                parseDashboardPayload(event.data)
            }
            sseState = .disconnected
        }
    }

    func stopStreaming() {
        sseTask?.cancel()
        sseTask = nil
        Task { await sseClient.disconnect() }
    }

    func refresh() async {
        do {
            let payload: DashboardPayload = try await apiClient.request(.dashboard)
            agents = payload.agents ?? []
            summary = payload.summary
            error = nil
            saveToCache(payload)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Cache (UserDefaults)

    private func saveToCache(_ payload: DashboardPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    private func restoreFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let payload = try? JSONDecoder().decode(DashboardPayload.self, from: data) else { return }
        agents = payload.agents ?? []
        summary = payload.summary
    }

    // MARK: - Private

    private func parseDashboardPayload(_ data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        do {
            let payload = try JSONDecoder().decode(DashboardPayload.self, from: jsonData)
            agents = payload.agents ?? agents
            if let s = payload.summary { summary = s }
            error = nil
            saveToCache(payload)
        } catch {
            // Partial payload — ignore decode errors
        }
    }

    private func updateSSEState() async {
        sseState = await sseClient.getState()
    }
}

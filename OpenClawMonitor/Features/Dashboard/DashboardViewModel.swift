import Foundation
import SwiftUI

@Observable @MainActor
final class DashboardViewModel {
    var agents: [Agent] = []
    var summary: DashboardSummary?
    var sseState: SSEConnectionState = .disconnected
    var error: String?

    private let apiClient: APIClient
    private let sseClient: SSEClient
    private var sseTask: Task<Void, Never>?

    init(apiClient: APIClient, sseClient: SSEClient) {
        self.apiClient = apiClient
        self.sseClient = sseClient
    }

    func startStreaming() {
        sseTask?.cancel()
        sseTask = Task {
            let stream = await sseClient.connect(endpoint: .dashboardStream)
            for await event in stream {
                await updateSSEState()
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
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseDashboardPayload(_ data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        do {
            let payload = try JSONDecoder().decode(DashboardPayload.self, from: jsonData)
            agents = payload.agents ?? agents
            if let s = payload.summary { summary = s }
            error = nil
        } catch {
            // Partial payload — ignore decode errors for non-standard events
        }
    }

    private func updateSSEState() async {
        sseState = await sseClient.state
    }
}

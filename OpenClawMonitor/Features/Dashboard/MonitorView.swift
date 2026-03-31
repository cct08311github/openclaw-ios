import SwiftUI

enum MonitorSection: String, CaseIterable {
    case agents = "Agents"
    case cron = "Cron"
    case tasks = "Tasks"
}

struct MonitorView: View {
    let apiClient: any APIClientProtocol
    let sseClient: any SSEClientProtocol
    @Environment(AuthManager.self) private var auth
    @State private var selectedSection: MonitorSection = .agents

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSection) {
                    ForEach(MonitorSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedSection {
                case .agents:
                    DashboardView(
                        apiClient: apiClient,
                        sseClient: sseClient,
                        onUnauthorized: { auth.handleUnauthorized() }
                    )
                case .cron:
                    CronView(apiClient: apiClient)
                case .tasks:
                    TaskHubView(apiClient: apiClient)
                }
            }
            .navigationTitle("監控")
        }
    }
}

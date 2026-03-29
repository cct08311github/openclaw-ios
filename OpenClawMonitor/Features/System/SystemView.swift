import SwiftUI

struct SystemView: View {
    @State private var viewModel: SystemViewModel

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: SystemViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            List {
                // Health
                if let health = viewModel.health {
                    Section("健康狀態") {
                        LabeledContent("狀態", value: health.status ?? "—")
                        LabeledContent("安全等級", value: health.securityLevel ?? "—")
                    }
                }

                // Dependencies
                if !viewModel.dependencies.isEmpty {
                    Section("相依服務") {
                        ForEach(viewModel.dependencies) { dep in
                            HStack {
                                Image(systemName: dep.status == "ok" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(dep.status == "ok" ? .green : .red)
                                VStack(alignment: .leading) {
                                    Text(dep.name).font(.headline)
                                    if let msg = dep.message {
                                        Text(msg).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Alerts
                Section("最近警報 (\(viewModel.alerts.count))") {
                    if viewModel.alerts.isEmpty {
                        Text("無警報").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.alerts) { alert in
                        HStack(spacing: 8) {
                            AlertSeverityIcon(severity: alert.severity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.message ?? "—")
                                    .font(.subheadline)
                                HStack {
                                    if let source = alert.source {
                                        Text(source).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    if let ts = alert.timestamp {
                                        Text(formatTs(ts)).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("系統")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    private func formatTs(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh-Hant")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AlertSeverityIcon: View {
    let severity: AlertSeverity?

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(color)
    }

    private var icon: String {
        switch severity {
        case .error: "exclamationmark.octagon.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .info, nil: "info.circle.fill"
        }
    }

    private var color: Color {
        switch severity {
        case .error: .red
        case .warn: .orange
        case .info, nil: .blue
        }
    }
}

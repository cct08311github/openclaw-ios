import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol, sseClient: any SSEClientProtocol) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: DashboardViewModel(apiClient: apiClient, sseClient: sseClient))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ConnectionBadge(state: viewModel.sseState)

                if let summary = viewModel.summary {
                    SummaryCardsView(summary: summary)
                }

                LazyVStack(spacing: 8) {
                    ForEach(viewModel.agents) { agent in
                        NavigationLink {
                            AgentDetailView(apiClient: apiClient, agent: agent)
                        } label: {
                            AgentCardView(agent: agent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.agents.isEmpty && viewModel.error == nil {
                    ContentUnavailableView("載入中...", systemImage: "arrow.trianglehead.2.clockwise")
                }

                if let error = viewModel.error {
                    ContentUnavailableView("錯誤", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
        .onAppear { viewModel.startStreaming() }
        .onDisappear { viewModel.stopStreaming() }
    }
}

// MARK: - Connection Badge

struct ConnectionBadge: View {
    let state: SSEConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var dotColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        }
    }

    private var label: String {
        switch state {
        case .connected: "即時連線"
        case .connecting: "連線中..."
        case .disconnected: "已斷線"
        }
    }
}

// MARK: - Summary Cards

struct SummaryCardsView: View {
    let summary: DashboardSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(title: "Agents", value: "\(summary.totalAgents ?? 0)", icon: "person.3", color: .blue)
            SummaryCard(title: "Active", value: "\(summary.activeAgents ?? 0)", icon: "bolt.fill", color: .green)
            SummaryCard(title: "Sub-Agents", value: "\(summary.subAgentCount ?? 0)", icon: "person.2", color: .cyan)
            SummaryCard(title: "月費用", value: formatCost(summary.monthlyCostTWD), icon: "dollarsign.circle", color: .orange)
        }
    }

    private func formatCost(_ cost: Double?) -> String {
        guard let cost else { return "—" }
        return "NT$\(Int(cost))"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Agent Card

struct AgentCardView: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 12) {
            Text(agent.emoji ?? "🤖")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.label ?? agent.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    StatusBadge(status: agent.status)
                    if let model = agent.model {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let activity = agent.lastActivity {
                Text(activity)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(agent.label ?? agent.name), 狀態: \(agent.status.rawValue)")
    }
}

struct StatusBadge: View {
    let status: AgentStatus

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .activeExecuting: "執行中"
        case .activeRecent: "活躍"
        case .activeHistorical: "近期"
        case .dormant: "休眠"
        case .inactive: "未啟用"
        case .error: "錯誤"
        }
    }

    private var color: Color {
        switch status {
        case .activeExecuting: .green
        case .activeRecent: .blue
        case .activeHistorical: .cyan
        case .dormant: .gray
        case .inactive: .secondary
        case .error: .red
        }
    }
}

import SwiftUI

struct CronView: View {
    @State private var viewModel: CronViewModel
    @State private var confirmRun: CronJob?
    @State private var confirmDelete: CronJob?

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: CronViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            ForEach(viewModel.jobs) { job in
                CronJobRow(
                    job: job,
                    onToggle: { Task { await viewModel.toggle(id: job.id) } },
                    onRun: { confirmRun = job },
                    onDelete: { confirmDelete = job }
                )
            }
        }
        .overlay {
            if viewModel.jobs.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("沒有 Cron Jobs", systemImage: "clock.badge.questionmark")
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .confirmationDialog("確定要立即執行？", isPresented: .init(
            get: { confirmRun != nil },
            set: { if !$0 { confirmRun = nil } }
        )) {
            if let job = confirmRun {
                Button("執行 \(job.name ?? job.id)") {
                    Haptics.medium()
                    Task { await viewModel.run(id: job.id) }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("確定要刪除？", isPresented: .init(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            if let job = confirmDelete {
                Button("刪除 \(job.name ?? job.id)", role: .destructive) {
                    Haptics.warning()
                    Task { await viewModel.delete(id: job.id) }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

struct CronJobRow: View {
    let job: CronJob
    let onToggle: () -> Void
    let onRun: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name ?? job.id)
                    .font(.headline)
                HStack(spacing: 12) {
                    if let state = job.state {
                        Label(statusLabel(state.lastStatus), systemImage: statusIcon(state.lastStatus))
                            .font(.caption2)
                            .foregroundStyle(statusColor(state.lastStatus))
                        if let next = state.nextRunAtMs {
                            Text("下次: \(formatMs(next))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Toggle("", isOn: .init(
                get: { job.enabled ?? false },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("刪除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { onRun() } label: {
                Label("執行", systemImage: "play.fill")
            }
            .tint(.green)
        }
    }

    private func statusLabel(_ status: String?) -> String {
        switch status {
        case "ok": "成功"
        case "error": "錯誤"
        default: "未知"
        }
    }

    private func statusIcon(_ status: String?) -> String {
        switch status {
        case "ok": "checkmark.circle.fill"
        case "error": "xmark.circle.fill"
        default: "questionmark.circle"
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "ok": .green
        case "error": .red
        default: .secondary
        }
    }

    private func formatMs(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh-Hant")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

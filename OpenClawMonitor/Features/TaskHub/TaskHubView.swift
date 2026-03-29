import SwiftUI

struct TaskHubView: View {
    @State private var viewModel: TaskHubViewModel

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: TaskHubViewModel(apiClient: apiClient))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Domain picker
            if !viewModel.domains.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DomainChip(label: "全部", isSelected: viewModel.selectedDomain == nil) {
                            viewModel.selectedDomain = nil
                            Task { await viewModel.load() }
                        }
                        ForEach(viewModel.domains, id: \.self) { domain in
                            DomainChip(label: domain, isSelected: viewModel.selectedDomain == domain) {
                                viewModel.selectedDomain = domain
                                Task { await viewModel.load() }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            // Task list
            List {
                ForEach(viewModel.tasks) { task in
                    TaskRow(task: task) { newStatus in
                        Task { await viewModel.updateStatus(task: task, newStatus: newStatus) }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteTask(task) }
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if viewModel.tasks.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("沒有任務", systemImage: "tray")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showNewTaskSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showNewTaskSheet) {
            NewTaskSheet(viewModel: viewModel)
        }
    }
}

struct NewTaskSheet: View {
    @Bindable var viewModel: TaskHubViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("標題", text: $viewModel.newTitle)
                TextField("Domain", text: $viewModel.newDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("優先級", selection: $viewModel.newPriority) {
                    Text("Low").tag(TaskPriority.low)
                    Text("Medium").tag(TaskPriority.medium)
                    Text("High").tag(TaskPriority.high)
                }
            }
            .navigationTitle("新增任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.showNewTaskSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task { await viewModel.createTask() }
                    }
                    .disabled(viewModel.newTitle.isEmpty || viewModel.newDomain.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct DomainChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

struct TaskRow: View {
    let task: OCTask
    let onStatusChange: (TaskStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title ?? "Untitled")
                    .font(.headline)
                Spacer()
                PriorityBadge(priority: task.priority)
            }

            HStack(spacing: 8) {
                if let domain = task.domain {
                    Text(domain)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                Menu {
                    ForEach([TaskStatus.backlog, .inProgress, .blocked, .done], id: \.rawValue) { status in
                        Button(statusLabel(status)) { onStatusChange(status) }
                    }
                } label: {
                    TaskStatusBadge(status: task.status)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusLabel(_ status: TaskStatus) -> String {
        switch status {
        case .backlog: "Backlog"
        case .inProgress: "進行中"
        case .blocked: "阻塞"
        case .done: "完成"
        }
    }
}

struct TaskStatusBadge: View {
    let status: TaskStatus?

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .backlog: "Backlog"
        case .inProgress: "進行中"
        case .blocked: "阻塞"
        case .done: "完成"
        case nil: "—"
        }
    }

    private var color: Color {
        switch status {
        case .backlog: .secondary
        case .inProgress: .blue
        case .blocked: .orange
        case .done: .green
        case nil: .secondary
        }
    }
}

struct PriorityBadge: View {
    let priority: TaskPriority?

    var body: some View {
        if let priority {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    private var icon: String {
        switch priority {
        case .high: "exclamationmark.triangle.fill"
        case .medium: "minus.circle.fill"
        case .low: "arrow.down.circle.fill"
        case nil: "circle"
        }
    }

    private var color: Color {
        switch priority {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case nil: .secondary
        }
    }
}

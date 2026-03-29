import SwiftUI

@Observable @MainActor
final class DebugLogViewModel {
    var entries: [LogEntry] = []
    var filterLevel: AppLogLevel? = nil
    var filterCategory: LogCategory? = nil
    var searchText = ""

    var filteredEntries: [LogEntry] {
        entries.filter { entry in
            (filterLevel == nil || entry.level >= filterLevel!) &&
            (filterCategory == nil || entry.category == filterCategory) &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    func refresh() async {
        if let level = filterLevel {
            entries = await AppLogger.shared.getEntries(level: level, category: filterCategory)
        } else {
            entries = await AppLogger.shared.getEntries(category: filterCategory)
        }
    }

    func clear() async {
        await AppLogger.shared.clear()
        entries = []
    }
}

struct DebugLogView: View {
    @State private var viewModel = DebugLogViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                HStack(spacing: 8) {
                    Menu {
                        Button("全部") { viewModel.filterLevel = nil }
                        ForEach(AppLogLevel.allCases, id: \.rawValue) { level in
                            Button(level.rawValue.uppercased()) { viewModel.filterLevel = level }
                        }
                    } label: {
                        Label(viewModel.filterLevel?.rawValue.uppercased() ?? "Level", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                    }

                    Menu {
                        Button("全部") { viewModel.filterCategory = nil }
                        ForEach(LogCategory.allCases, id: \.rawValue) { cat in
                            Button(cat.rawValue) { viewModel.filterCategory = cat }
                        }
                    } label: {
                        Label(viewModel.filterCategory?.rawValue ?? "Category", systemImage: "tag")
                            .font(.caption)
                    }

                    Spacer()

                    Text("\(viewModel.filteredEntries.count) entries")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()

                // Log entries
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.filteredEntries) { entry in
                                DebugLogEntryView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .background(Color(white: 0.06))
                    .onChange(of: viewModel.filteredEntries.count) { _, _ in
                        if let last = viewModel.filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "搜尋...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("重新整理", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("清除", systemImage: "trash", role: .destructive) {
                        Task { await viewModel.clear() }
                    }
                }
            }
            .task { await viewModel.refresh() }
        }
    }
}

struct DebugLogEntryView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(levelIcon)
                .font(.caption2)

            Text(formatTime(entry.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .leading)

            Text(entry.category.rawValue)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.cyan)
                .frame(width: 55, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(levelColor)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var levelIcon: String {
        switch entry.level {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .warning: "⚠️"
        case .error: "❌"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: Color(white: 0.5)
        case .info: Color(white: 0.8)
        case .warning: .yellow
        case .error: .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

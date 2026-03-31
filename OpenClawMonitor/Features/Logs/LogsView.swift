import SwiftUI

struct LogsView: View {
    @State private var viewModel: LogsViewModel

    init(sseClient: any SSEClientProtocol, onUnauthorized: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: LogsViewModel(sseClient: sseClient, onUnauthorized: onUnauthorized))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    ConnectionBadge(state: viewModel.sseState)
                    Spacer()
                    Toggle("Errors", isOn: $viewModel.errorOnly)
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .tint(.red)
                    Button("清除", systemImage: "trash") {
                        viewModel.clear()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Log content
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(viewModel.filteredLines) { line in
                                LogLineView(line: line)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .background(Color(white: 0.08))
                    .onChange(of: viewModel.lines.count) { _, _ in
                        if let last = viewModel.filteredLines.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("日誌")
            .searchable(text: $viewModel.searchText, prompt: "搜尋日誌...")
            .onAppear { viewModel.startStreaming() }
            .onDisappear { viewModel.stopStreaming() }
        }
    }
}

struct LogLineView: View {
    let line: LogLine

    var body: some View {
        Text(line.text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(lineColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private var lineColor: Color {
        switch line.level {
        case .error: .red
        case .warning: .yellow
        case .normal: Color(white: 0.8)
        }
    }
}

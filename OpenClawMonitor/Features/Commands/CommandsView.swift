import SwiftUI

struct CommandBody: Encodable {
    let command: String
    var agentId: String?
    var message: String?
    var model: String?
}

@Observable @MainActor
final class CommandsViewModel {
    var output: String = ""
    var isExecuting = false
    var error: String?

    // Chat
    var selectedAgent: String = ""
    var chatMessage: String = ""
    var chatHistory: [(role: String, text: String)] = []

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func execute(command: String, agentId: String? = nil, message: String? = nil) async {
        isExecuting = true
        error = nil
        defer { isExecuting = false }

        let body = CommandBody(command: command, agentId: agentId, message: message)
        do {
            struct CmdResponse: Decodable {
                let success: Bool
                let output: String?
                let error: String?
            }
            let response: CmdResponse = try await apiClient.request(.command(body: body))
            if response.success {
                output = response.output ?? "✅ 執行成功"
            } else {
                error = response.error ?? "執行失敗"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendChat() async {
        guard !chatMessage.isEmpty, !selectedAgent.isEmpty else { return }
        let msg = chatMessage
        chatMessage = ""
        chatHistory.append((role: "user", text: msg))

        await execute(command: "talk", agentId: selectedAgent, message: msg)
        if let out = error == nil ? output : nil, !out.isEmpty {
            chatHistory.append((role: "assistant", text: out))
        }
    }
}

struct CommandsView: View {
    @State private var viewModel: CommandsViewModel
    @State private var confirmRestart = false
    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: CommandsViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick actions
                Section("快速指令") {
                    Button { Task { await viewModel.execute(command: "status") } } label: {
                        Label("Status", systemImage: "heart.text.square")
                    }
                    Button { confirmRestart = true } label: {
                        Label("Restart Gateway", systemImage: "arrow.clockwise")
                            .foregroundStyle(.red)
                    }
                }

                // Output
                if !viewModel.output.isEmpty || viewModel.error != nil {
                    Section("輸出") {
                        if viewModel.isExecuting {
                            ProgressView()
                        }
                        if let error = viewModel.error {
                            Text(error).foregroundStyle(.red).font(.caption)
                        }
                        if !viewModel.output.isEmpty {
                            Text(viewModel.output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }

                // Chat
                Section("Chat") {
                    TextField("Agent ID", text: $viewModel.selectedAgent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    ForEach(Array(viewModel.chatHistory.enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top) {
                            Text(entry.role == "user" ? "👤" : "🤖")
                            Text(entry.text)
                                .font(.subheadline)
                        }
                    }

                    HStack {
                        TextField("訊息...", text: $viewModel.chatMessage)
                            .onSubmit { Task { await viewModel.sendChat() } }
                        Button {
                            Task { await viewModel.sendChat() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(viewModel.chatMessage.isEmpty || viewModel.selectedAgent.isEmpty)
                    }
                }
            }
            .navigationTitle("指令")
            .alert("確定重啟 Gateway？", isPresented: $confirmRestart) {
                Button("重啟", role: .destructive) {
                    Haptics.warning()
                    Task { await viewModel.execute(command: "restart") }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這會暫時中斷所有 agent 連線")
            }
        }
    }
}

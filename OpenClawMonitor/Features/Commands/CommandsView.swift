import SwiftUI

struct CommandBody: Encodable {
    let command: String
    var agentId: String?
    var message: String?
    var model: String?
}

struct ChatEntry: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

@Observable @MainActor
final class CommandsViewModel {
    var output: String = ""
    var isExecuting = false
    var error: String?

    // Chat
    var selectedAgent: String = ""
    var chatMessage: String = ""
    var chatHistory: [ChatEntry] = []
    var isLoadingHistory = false

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

    func loadChatHistory() async {
        guard !selectedAgent.isEmpty else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let sessions: SessionListResponse = try await apiClient.request(.sessions(agentId: selectedAgent))
            guard let latest = sessions.sessions?.first else {
                chatHistory = []
                return
            }
            let content: SessionContentResponse = try await apiClient.request(
                .sessionContent(agentId: selectedAgent, sessionId: latest.id)
            )
            chatHistory = (content.messages ?? []).compactMap { msg in
                guard let role = msg.role, let text = msg.content, !text.isEmpty else { return nil }
                return ChatEntry(role: role, text: text)
            }
        } catch {
            chatHistory = []
            self.error = "載入歷史失敗：\(error.localizedDescription)"
        }
    }

    func sendChat() async {
        guard !isExecuting, !chatMessage.isEmpty, !selectedAgent.isEmpty else { return }
        let msg = chatMessage
        chatMessage = ""
        chatHistory.append(ChatEntry(role: "user", text: msg))
        Haptics.light()

        await execute(command: "talk", agentId: selectedAgent, message: msg)
        if error == nil, !output.isEmpty {
            chatHistory.append(ChatEntry(role: "assistant", text: output))
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
                    HStack {
                        TextField("Agent ID", text: $viewModel.selectedAgent)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("載入") {
                            Task { await viewModel.loadChatHistory() }
                        }
                        .disabled(viewModel.selectedAgent.isEmpty)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if viewModel.isLoadingHistory {
                        ProgressView("載入歷史...")
                    }

                    ForEach(viewModel.chatHistory) { entry in
                        HStack(alignment: .top) {
                            Text(entry.role == "user" ? "👤" : "🤖")
                            Text(entry.text)
                                .font(.subheadline)
                                .textSelection(.enabled)
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

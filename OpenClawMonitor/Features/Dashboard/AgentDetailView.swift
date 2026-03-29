import SwiftUI

// MARK: - Models

struct SessionListResponse: Decodable {
    let success: Bool
    let sessions: [AgentSession]?
}

struct AgentSession: Codable, Identifiable {
    let id: String
    let createdAt: String?
    let messageCount: Int?
}

struct SessionContentResponse: Decodable {
    let success: Bool
    let messages: [SessionMessage]?
}

struct SessionMessage: Codable, Identifiable {
    let id: UUID
    let role: String?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decodeIfPresent(String.self, forKey: .role)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
    }
}

// MARK: - ViewModel

@Observable @MainActor
final class AgentDetailViewModel {
    var sessions: [AgentSession] = []
    var isLoading = false
    var error: String?

    private let apiClient: any APIClientProtocol
    let agent: Agent

    init(apiClient: any APIClientProtocol, agent: Agent) {
        self.apiClient = apiClient
        self.agent = agent
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SessionListResponse = try await apiClient.request(.sessions(agentId: agent.id))
            sessions = response.sessions ?? []
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSessionContent(_ session: AgentSession) async -> [SessionMessage] {
        do {
            let response: SessionContentResponse = try await apiClient.request(
                .sessionContent(agentId: agent.id, sessionId: session.id)
            )
            return response.messages ?? []
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }
}

// MARK: - Views

struct AgentDetailView: View {
    @State private var viewModel: AgentDetailViewModel

    init(apiClient: any APIClientProtocol, agent: Agent) {
        _viewModel = State(initialValue: AgentDetailViewModel(apiClient: apiClient, agent: agent))
    }

    var body: some View {
        List {
            // Agent info header
            Section {
                HStack(spacing: 12) {
                    Text(viewModel.agent.emoji ?? "🤖").font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.agent.label ?? viewModel.agent.name).font(.title3.bold())
                        StatusBadge(status: viewModel.agent.status)
                        if let model = viewModel.agent.model {
                            Text(model).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Sessions
            Section("Sessions (\(viewModel.sessions.count))") {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    Text("沒有 session").foregroundStyle(.secondary)
                }
                ForEach(viewModel.sessions) { session in
                    NavigationLink {
                        SessionContentView(viewModel: viewModel, session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.id).font(.caption.monospaced()).lineLimit(1)
                            HStack {
                                if let created = session.createdAt {
                                    Text(created).font(.caption2).foregroundStyle(.secondary)
                                }
                                if let count = session.messageCount {
                                    Text("\(count) msgs").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if let error = viewModel.error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(viewModel.agent.label ?? viewModel.agent.name)
        .task { await viewModel.loadSessions() }
    }
}

struct SessionContentView: View {
    let viewModel: AgentDetailViewModel
    let session: AgentSession

    @State private var messages: [SessionMessage] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(messages) { msg in
                    HStack(alignment: .top, spacing: 8) {
                        Text(msg.role == "user" ? "👤" : "🤖")
                            .font(.caption)
                        Text(msg.content ?? "")
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Session")
        .overlay {
            if isLoading {
                ProgressView()
            }
            if !isLoading && messages.isEmpty {
                ContentUnavailableView("空 session", systemImage: "text.bubble")
            }
        }
        .task {
            messages = await viewModel.loadSessionContent(session)
            isLoading = false
        }
    }
}

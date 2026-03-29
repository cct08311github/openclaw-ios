import SwiftUI

@main
struct OpenClawMonitorApp: App {
    // MARK: - Configuration
    // TODO: Make this configurable via Settings screen
    private static let serverURL = URL(string: "https://100.94.135.81:3001")!

    // MARK: - Dependencies
    @State private var apiClient: APIClient
    @State private var authManager: AuthManager
    @State private var connectivity = ConnectivityMonitor()
    @State private var dashboardSSE: SSEClient
    @State private var logsSSE: SSEClient

    init() {
        let client = APIClient(baseURL: Self.serverURL)
        let auth = AuthManager(apiClient: client)
        let tokenProvider: @Sendable () -> String? = { AuthManager.loadTokenStatic() }
        let dashSSE = SSEClient(baseURL: Self.serverURL, tokenProvider: tokenProvider)
        let logSSE = SSEClient(baseURL: Self.serverURL, tokenProvider: tokenProvider)

        _apiClient = State(initialValue: client)
        _authManager = State(initialValue: auth)
        _dashboardSSE = State(initialValue: dashSSE)
        _logsSSE = State(initialValue: logSSE)
    }

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, dashboardSSE: dashboardSSE, logsSSE: logsSSE)
                .environment(authManager)
                .environment(connectivity)
                .task { @MainActor in
                    if Self.isUITesting {
                        // Skip real network calls in UI tests — force authenticated state
                        authManager.isAuthenticated = true
                        authManager.username = "uitest"
                    } else {
                        connectivity.start()
                        await authManager.restoreSession()
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}

import SwiftUI

@main
struct OpenClawMonitorApp: App {
    // MARK: - Configuration
    // TODO: Make this configurable via Settings
    private static let serverURL = URL(string: "https://100.94.135.81:3001")!

    // MARK: - Dependencies
    @State private var apiClient: APIClient
    @State private var authManager: AuthManager
    @State private var connectivity = ConnectivityMonitor()

    init() {
        let client = APIClient(baseURL: Self.serverURL)
        let auth = AuthManager(apiClient: client)
        _apiClient = State(initialValue: client)
        _authManager = State(initialValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(connectivity)
                .task { @MainActor in
                    connectivity.start()
                    await authManager.restoreSession()
                }
                .preferredColorScheme(.dark)
        }
    }
}

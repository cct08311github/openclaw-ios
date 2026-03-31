import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ConnectivityMonitor.self) private var connectivity
    let apiClient: any APIClientProtocol
    let dashboardSSE: any SSEClientProtocol
    let logsSSE: any SSEClientProtocol

    var body: some View {
        if auth.isAuthenticated {
            MainTabView(apiClient: apiClient, dashboardSSE: dashboardSSE, logsSSE: logsSSE)
                .overlay(alignment: .top) {
                    if !connectivity.isConnected {
                        OfflineBanner()
                    }
                }
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    let apiClient: any APIClientProtocol
    let dashboardSSE: any SSEClientProtocol
    let logsSSE: any SSEClientProtocol

    @Environment(AuthManager.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var alertCount = 0
    @State private var backgroundTask: Task<Void, Never>?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MonitorView(apiClient: apiClient, sseClient: dashboardSSE)
                .tabItem {
                    Label("監控", systemImage: "rectangle.grid.2x2")
                }
                .tag(0)
            LogsView(sseClient: logsSSE, onUnauthorized: { auth.handleUnauthorized() })
                .tabItem {
                    Label("日誌", systemImage: "text.justify.left")
                }
                .tag(1)
            SystemView(apiClient: apiClient, alertCount: $alertCount)
                .tabItem {
                    Label("系統", systemImage: "chart.bar")
                }
                .tag(2)
                .badge(alertCount)
            CommandsView(apiClient: apiClient)
                .tabItem {
                    Label("指令", systemImage: "terminal")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { _, newTab in
            // 進入系統 tab 後清除 badge
            if newTab == 2 {
                alertCount = 0
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                backgroundTask?.cancel()
                backgroundTask = Task {
                    await dashboardSSE.disconnect()
                    await logsSSE.disconnect()
                }
            case .active where oldPhase == .background:
                backgroundTask?.cancel()
                backgroundTask = nil
                // Reconnect is handled by onAppear in each view
            default:
                break
            }
        }
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("網路已斷線")
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.red.gradient)
    }
}

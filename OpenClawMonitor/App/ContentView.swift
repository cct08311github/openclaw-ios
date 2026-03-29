import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ConnectivityMonitor.self) private var connectivity
    let apiClient: APIClient
    let dashboardSSE: SSEClient
    let logsSSE: SSEClient

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
    let apiClient: APIClient
    let dashboardSSE: SSEClient
    let logsSSE: SSEClient

    var body: some View {
        TabView {
            Tab("監控", systemImage: "rectangle.grid.2x2") {
                MonitorView(apiClient: apiClient, sseClient: dashboardSSE)
            }
            Tab("日誌", systemImage: "text.justify.left") {
                LogsView(sseClient: logsSSE)
            }
            Tab("系統", systemImage: "chart.bar") {
                SystemView(apiClient: apiClient)
            }
            Tab("指令", systemImage: "terminal") {
                CommandsView(apiClient: apiClient)
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

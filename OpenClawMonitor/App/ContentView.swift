import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ConnectivityMonitor.self) private var connectivity

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
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
    var body: some View {
        TabView {
            Tab("監控", systemImage: "rectangle.grid.2x2") {
                DashboardPlaceholder()
            }
            Tab("日誌", systemImage: "text.justify.left") {
                LogsPlaceholder()
            }
            Tab("系統", systemImage: "chart.bar") {
                SystemPlaceholder()
            }
            Tab("指令", systemImage: "terminal") {
                CommandsPlaceholder()
            }
        }
    }
}

// MARK: - Placeholders (will be replaced in Phase 2-5)

private struct DashboardPlaceholder: View {
    var body: some View {
        NavigationStack {
            Text("Dashboard — Phase 2")
                .navigationTitle("監控")
        }
    }
}

private struct LogsPlaceholder: View {
    var body: some View {
        NavigationStack {
            Text("Logs — Phase 2")
                .navigationTitle("日誌")
        }
    }
}

private struct SystemPlaceholder: View {
    var body: some View {
        NavigationStack {
            Text("System — Phase 4")
                .navigationTitle("系統")
        }
    }
}

private struct CommandsPlaceholder: View {
    var body: some View {
        NavigationStack {
            Text("Commands — Phase 5")
                .navigationTitle("指令")
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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OpenClawMonitor** is an iOS app (iOS 18.0+) that monitors the OpenClaw AI agent system. It connects via REST API and Server-Sent Events (SSE) to display agent status, logs, cron jobs, system metrics, and allows sending commands.

## Build Commands

```bash
xcodegen generate        # Generate .xcodeproj from project.yml
xcodebuild -scheme OpenClawMonitor -destination 'platform=iOS Simulator,name=iPhone 16' build

# Testing
xcodebuild test -scheme OpenClawMonitor -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -scheme OpenClawMonitorTests                # Unit + Integration only
xcodebuild test -scheme OpenClawMonitorUITests              # UITests only
```

## Architecture

### App Entry
- `OpenClawMonitorApp.swift` — Configures server URL (`https://100.94.135.81:3001`), initializes `APIClient`, `AuthManager`, and two `SSEClient` instances (dashboard + logs)
- `ContentView.swift` — Root view; checks `AuthManager.isAuthenticated` → shows login or `MainTabView`

### Tab Structure
| Tab | View | Purpose |
|-----|------|---------|
| 監控 | `MonitorView` | Real-time agent dashboard via SSE |
| 日誌 | `LogsView` | Log stream viewer |
| 系統 | `SystemView` | System metrics and alerts |
| 指令 | `CommandsView` | Send commands to agents |

### Networking
- **`APIClient`** — REST client with retry logic (exponential backoff), Bearer token auth, delegates SSL trust to `TrustAllDelegate` for self-signed certs (mkcert/Tailscale)
- **`SSEClient`** — Server-Sent Events streaming client for real-time updates
- **`Endpoint`** — Enum of all API endpoints with static constructors

### State Management
- Swift **Observation framework** (`@Observable`) for ViewModels
- `AuthManager` stored as `@Environment`, provides `isAuthenticated`, `login()`, `logout()`, session restore via Keychain

### Data Flow
```
APIClient/SSEClient → ViewModels → SwiftUI Views
                         ↓
                  DashboardViewModel (caches to UserDefaults)
```

### Models
- `Agent` / `DashboardPayload` — Agent registry and dashboard state
- `CronJob` — Scheduled job definitions
- `Task` — TaskHub task representation
- `Alert` — System alerts

## Testing Structure

| Suite | Location | Count |
|-------|----------|-------|
| Unit | `Tests/Unit/` | 11 test files |
| Integration | `Tests/Integration/` | 6 ViewModel tests + mocks |
| UITests | `Tests/UITests/E2E/` | 6 flow tests |

Mock infrastructure: `MockAPIClient`, `MockSSEClient`, `MockURLProtocol` for deterministic testing.

## Important Notes

- **Server URL**: Hardcoded in `OpenClawMonitorApp.swift` — update for different deployments
- **SSL**: `TrustAllDelegate` trusts all certificates — only for local development with self-signed certs
- **Session**: Tokens stored in macOS/iOS Keychain via `AuthManager`
- **SSE Reconnection**: Handled automatically; views reconnect on `scenePhase` change (background → active)

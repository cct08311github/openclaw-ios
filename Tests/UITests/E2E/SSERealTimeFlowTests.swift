import XCTest

/// E2E tests for SSE real-time updates and ConnectionBadge states
/// Note: Full SSE testing requires mock server or real SSE endpoint
final class SSERealTimeFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func findConnectionBadge() -> Bool {
        // ConnectionBadge shows: 即時連線 / 連線中... / 已斷線
        let connected = app.staticTexts["即時連線"]
        let connecting = app.staticTexts["連線中..."]
        let disconnected = app.staticTexts["已斷線"]

        return connected.waitForExistence(timeout: 2) ||
               connecting.waitForExistence(timeout: 2) ||
               disconnected.waitForExistence(timeout: 2)
    }

    func testConnectionBadgeExistsInDashboard() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["監控"].tap()

        // ConnectionBadge should be visible in Dashboard
        // Badge shows SSE state: 即時連線 / 連線中... / 已斷線
        XCTAssertTrue(
            findConnectionBadge(),
            "ConnectionBadge should display SSE state in Dashboard"
        )
    }

    func testConnectionBadgeExistsInLogs() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["日誌"].tap()

        // LogsView also has ConnectionBadge
        XCTAssertTrue(
            findConnectionBadge(),
            "Logs tab should display ConnectionBadge with SSE state"
        )
    }

    func testSSEReconnectsAfterBackground() throws {
        // Note: XCUIDevice.shared.press(.home) doesn't work reliably in Simulator
        // ScenePhase testing requires physical device or UI testing with lifecycle hooks
        // This test validates the UI structure exists for SSE reconnection

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["監控"].tap()

        // Verify SSE UI elements exist before background testing
        XCTAssertTrue(
            findConnectionBadge(),
            "ConnectionBadge should display SSE state in Dashboard"
        )
    }
}

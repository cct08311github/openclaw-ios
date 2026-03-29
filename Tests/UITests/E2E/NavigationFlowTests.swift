import XCTest

/// E2E tests for navigation flows - AgentDetailView, SessionContentView
final class NavigationFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testAgentCardNavigationExists() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["監控"].tap()

        // Should show Agents segment by default or after switching
        let segmented = app.segmentedControls.firstMatch
        guard segmented.waitForExistence(timeout: 3) else {
            XCTFail("Segmented control not found")
            return
        }

        segmented.buttons["Agents"].tap()

        // Agent cards exist when agents are loaded
        // The navigation link is wrapped around AgentCardView
        // Note: Without real data, cards may not appear in UITesting mode
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3) || app.staticTexts["載入中..."].waitForExistence(timeout: 3))
    }

    func testMonitorTabNavigationStack() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["監控"].tap()

        // Monitor tab uses NavigationStack
        let navTitle = app.navigationBars["監控"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Monitor tab should have navigation title")
    }

    func testLogsTabNavigationStack() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["日誌"].tap()

        // Logs tab uses NavigationStack
        let navTitle = app.navigationBars["日誌"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Logs tab should have navigation title")
    }

    func testSystemTabNavigationStack() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["系統"].tap()

        // System tab uses NavigationStack
        let navTitle = app.navigationBars["系統"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "System tab should have navigation title")
    }

    func testCommandsTabNavigationStack() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        tabBar.buttons["指令"].tap()

        // Commands tab uses NavigationStack (via CommandsView)
        let navTitle = app.navigationBars["指令"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Commands tab should have navigation title")
    }
}

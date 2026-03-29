import XCTest

final class DashboardFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testMonitorTabShowsSegmentedControl() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }
        // Tap the monitor tab
        tabBar.buttons["監控"].tap()

        // Segmented control should show Agents/Cron/Tasks
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 3))
    }

    func testCanSwitchBetweenSegments() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }
        tabBar.buttons["監控"].tap()

        let segmented = app.segmentedControls.firstMatch
        guard segmented.waitForExistence(timeout: 3) else {
            XCTFail("Segmented control not found")
            return
        }

        segmented.buttons["Cron"].tap()
        segmented.buttons["Tasks"].tap()
        segmented.buttons["Agents"].tap()
    }
}

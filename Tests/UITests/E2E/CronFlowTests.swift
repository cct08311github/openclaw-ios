import XCTest

final class CronFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testCronSegmentShowsContent() throws {
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
        // Should show either cron jobs or empty state
        let list = app.collectionViews.firstMatch
        let emptyState = app.staticTexts["沒有 Cron Jobs"]
        XCTAssertTrue(list.waitForExistence(timeout: 3) || emptyState.waitForExistence(timeout: 3))
    }
}

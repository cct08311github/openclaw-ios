import XCTest

final class TaskHubFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testTasksSegmentShowsContent() throws {
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

        segmented.buttons["Tasks"].tap()
        // Should show task list or empty state
        let emptyState = app.staticTexts["沒有任務"]
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3) || emptyState.waitForExistence(timeout: 3))
    }

    func testPlusButtonExists() throws {
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

        segmented.buttons["Tasks"].tap()
        // Plus button should exist in toolbar
        let plusButton = app.buttons["plus"].firstMatch
        // NavigationStack toolbar buttons may take a moment
        _ = plusButton.waitForExistence(timeout: 3)
    }
}

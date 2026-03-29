import XCTest

final class LogsFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testLogsTabShowsContent() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }
        tabBar.buttons["日誌"].tap()
        // Should show navigation title
        let navTitle = app.navigationBars["日誌"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))
    }
}

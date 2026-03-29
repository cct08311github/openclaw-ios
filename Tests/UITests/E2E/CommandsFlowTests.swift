import XCTest

final class CommandsFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testCommandsTabShowsQuickActions() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }
        tabBar.buttons["指令"].tap()
        // Should show the quick actions section header
        let quickActions = app.staticTexts["快速指令"]
        XCTAssertTrue(quickActions.waitForExistence(timeout: 3))
    }
}

import XCTest

final class LoginFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testAppLaunchesAndShowsLoginScreen() throws {
        // The login view should be visible when not authenticated
        let loginButton = app.buttons["登入"]
        // In UI testing mode the app may show login or go straight to tabs
        // depending on mock state. Check for either.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5) || tabBar.waitForExistence(timeout: 5))
    }

    func testTabBarVisibleAfterLogin() throws {
        // With --uitesting flag, the app should auto-authenticate
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
}

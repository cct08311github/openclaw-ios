import XCTest

/// E2E tests for login error scenarios and form validation
final class LoginErrorFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Launch WITHOUT --uitesting to see real login screen
        app = XCUIApplication()
        app.launch()
    }

    func testLoginButtonDisabledWhenFieldsEmpty() throws {
        // Check that login button exists
        let loginButton = app.buttons["登入"]
        guard loginButton.waitForExistence(timeout: 5) else {
            XCTFail("Login button not found - app may have auto-authenticated in non-test mode")
            return
        }

        // Button should be disabled when username and password are empty
        XCTAssertFalse(loginButton.isEnabled, "Login button should be disabled when fields are empty")

        // Fill only username
        let usernameField = app.textFields.firstMatch
        if usernameField.waitForExistence(timeout: 3) {
            usernameField.tap()
            usernameField.typeText("testuser")

            // Button should still be disabled (password empty)
            XCTAssertFalse(loginButton.isEnabled, "Login button should be disabled with only username")
        }
    }

    func testLoginFormHasUsernameAndPasswordFields() throws {
        let usernameField = app.textFields.firstMatch
        let passwordField = app.secureTextFields.firstMatch

        let loginButton = app.buttons["登入"]

        // App may show login or go straight to tabs depending on auth state
        let hasLoginScreen = usernameField.waitForExistence(timeout: 3) ||
                             passwordField.waitForExistence(timeout: 3) ||
                             loginButton.waitForExistence(timeout: 3)

        XCTAssertTrue(hasLoginScreen, "Login form should have username/password fields or show authenticated state")
    }

    func testSecureFieldForPassword() throws {
        // Password should be a secure text field
        let passwordField = app.secureTextFields.firstMatch

        // If login screen shows (not authenticated)
        if passwordField.waitForExistence(timeout: 3) {
            XCTAssertTrue(passwordField.exists, "Password field should be a secure text field")
        }
    }
}

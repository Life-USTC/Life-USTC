import XCTest

final class Life_USTC_ScreenshotTests: XCTestCase {
    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TEST_RESET_ONBOARDING")
        setupSnapshot(app)
        app.launch()

        snapshot("01_Login")
        XCTAssertTrue(app.textFields["login_username_field"].waitForExistence(timeout: 10))
        app.textFields["login_username_field"].tap()
        app.textFields["login_username_field"].typeText("demo")
        XCTAssertTrue(app.secureTextFields["login_password_field"].waitForExistence(timeout: 5))
        app.secureTextFields["login_password_field"].tap()
        app.secureTextFields["login_password_field"].typeText("demo")
        app.tap()

        app.buttons["login_submit_button"].tap()
        snapshot("02_WelcomeView_1")

        app.buttons["onboarding_add_button"].tap()
        snapshot("03_WelcomeView_2")

        // Dismiss add course sheet if present, then finish onboarding
        if app.buttons["additional_course_done"].waitForExistence(timeout: 5) {
            app.buttons["additional_course_done"].tap()
        }

        snapshot("04_WelcomeView_3")

        if app.buttons["onboarding_done_button"].waitForExistence(timeout: 5) {
            app.buttons["onboarding_done_button"].tap()
        } else if app.buttons["onboarding_close_button"].waitForExistence(timeout: 2) {
            app.buttons["onboarding_close_button"].tap()
        }

        // Ensure tab bar is present
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // 04 Home
        snapshot("04_Home")

        // 05 Features (tab index 1)
        tabBar.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        snapshot("05_Features")

        // 06 Curriculum detail via feature tile
        if app.buttons["feature_curriculum"].waitForExistence(timeout: 5) {
            app.buttons["feature_curriculum"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            snapshot("06_Curriculum")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 07 Exam detail
        if app.buttons["feature_exam"].waitForExistence(timeout: 3) {
            app.buttons["feature_exam"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            snapshot("07_Exam")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 08 Score detail
        if app.buttons["feature_score"].waitForExistence(timeout: 3) {
            app.buttons["feature_score"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            snapshot("08_Score")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 09 Feed (tab index 2)
        tabBar.buttons.element(boundBy: 2).tap()
        snapshot("09_Feed")
    }
}

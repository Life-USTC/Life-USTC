import XCTest

final class Life_USTC_ScreenshotTests: XCTestCase {
    private func sidebarButton(in app: XCUIApplication, timeout: TimeInterval = 0) -> XCUIElement? {
        let labels = ["Sidebar", "边栏"]
        for label in labels {
            let button = app.buttons[label]
            if timeout > 0 {
                if button.waitForExistence(timeout: timeout) { return button }
            } else if button.exists {
                return button
            }
        }
        return nil
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TEST_RESET_ONBOARDING")
        setupSnapshot(app)
        app.launch()

        XCTAssertTrue(app.textFields["login_username_field"].waitForExistence(timeout: 10))
        app.textFields["login_username_field"].tap()
        app.textFields["login_username_field"].typeText("demo")
        XCTAssertTrue(app.secureTextFields["login_password_field"].waitForExistence(timeout: 5))
        app.secureTextFields["login_password_field"].tap()
        app.secureTextFields["login_password_field"].typeText("demo")
        app.tap()

        app.buttons["login_submit_button"].tap()

        app.buttons["onboarding_add_button"].tap()

        // Dismiss add course sheet if present, then finish onboarding
        if app.buttons["additional_course_done"].waitForExistence(timeout: 5) {
            app.buttons["additional_course_done"].tap()
        }

        if app.buttons["onboarding_done_button"].waitForExistence(timeout: 5) {
            app.buttons["onboarding_done_button"].tap()
        } else if app.buttons["onboarding_close_button"].waitForExistence(timeout: 2) {
            app.buttons["onboarding_close_button"].tap()
        }

        // Ensure tab bar or sidebar is present. On iPad the app uses a sidebar instead
        // of a bottom tab bar, so detect which UI is available and tap the
        // appropriate controls.
        let tabBar = app.tabBars.firstMatch
        let hasTabBar = tabBar.waitForExistence(timeout: 4)
        let tabBarCollapsed = sidebarButton(in: app, timeout: 4) != nil

        if !hasTabBar {
            // On iPad the sidebar buttons should exist (use visible tab labels)
            if tabBarCollapsed { sidebarButton(in: app)?.tap() }
            XCTAssertTrue(app.buttons["Tab.Features"].waitForExistence(timeout: 10))
            if tabBarCollapsed {
                app.tap()
            }
        }

        snapshot("04_Home")

        // 05 Features (tab index 1) — handle both tab bar and sidebar
        if hasTabBar {
            tabBar.buttons.element(boundBy: 1).tap()
        } else if tabBarCollapsed {
            sidebarButton(in: app)?.tap()
            app.buttons["Tab.Features"].tap()
            app.tap()
        } else {
            app.buttons["Tab.Features"].tap()
        }
        snapshot("05_Features")

        // 06 Curriculum detail via feature tile
        XCTAssertTrue(app.buttons["feature_curriculum"].waitForExistence(timeout: 5))
        app.buttons["feature_curriculum"].tap()
        snapshot("06_Curriculum")
        if hasTabBar {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 07 Exam detail
        XCTAssertTrue(app.buttons["feature_exam"].waitForExistence(timeout: 3))
        app.buttons["feature_exam"].tap()
        snapshot("07_Exam")
        if hasTabBar {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 08 Score detail
        XCTAssertTrue(app.buttons["feature_score"].waitForExistence(timeout: 3))
        app.buttons["feature_score"].tap()
        snapshot("08_Score")
        if hasTabBar {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 09 Feed (tab index 2)
        if hasTabBar {
            tabBar.buttons.element(boundBy: 2).tap()
        } else if tabBarCollapsed {
            sidebarButton(in: app)?.tap()
            app.buttons["Tab.Feed"].tap()
            app.tap()
        } else {
            app.buttons["Tab.Feed"].tap()
        }
        snapshot("09_Feed")
    }
}

import XCTest

final class Life_USTC_ScreenshotTests: XCTestCase {
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    private func selectTab(_ name: String, index: Int, in app: XCUIApplication) {
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: index).tap()
        } else {
            let tab = app.buttons["Tab.\(name)"]
            if !tab.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Sidebar should be available")
                toggle.tap()
            }
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab \(name) should exist")
            XCTAssertTrue(tab.isHittable, "Tab \(name) should be reachable")
            tab.tap()
        }
    }

    private func navigateBack(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Back control should be available")
        back.tap()
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()

        addUIInterruptionMonitor(withDescription: "Save Password") { (alert) -> Bool in
            let labels = ["Not Now", "以后", "Never for This Website", "不再提示"]
            for label in labels {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launchArguments.append("UI_TEST_RESET_ONBOARDING")
        setupSnapshot(app)
        app.launch()
        XCTAssertTrue(app.buttons["welcome_university"].waitForExistence(timeout: 10))
        app.buttons["welcome_university"].tap()

        XCTAssertTrue(app.textFields["login_username_field"].waitForExistence(timeout: 10))
        app.textFields["login_username_field"].tap()
        app.textFields["login_username_field"].typeText("demo")
        XCTAssertTrue(app.secureTextFields["login_password_field"].waitForExistence(timeout: 5))
        app.secureTextFields["login_password_field"].tap()
        app.secureTextFields["login_password_field"].typeText("demo")
        app.tap()

        app.buttons["login_submit_button"].tap()

        // Handle possible "Save Password" alert by backgrounding the app and returning.
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 5)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 5)

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

        selectTab("Home", index: 0, in: app)
        snapshot("04_Home")

        // 05 Features through Discover on both tab bar and sidebar layouts.
        selectTab("Discover", index: 2, in: app)
        app.buttons["discover_university"].tap()
        snapshot("05_Features")

        // 06 Curriculum detail via feature tile
        XCTAssertTrue(app.buttons["feature_curriculum"].waitForExistence(timeout: 5))
        app.buttons["feature_curriculum"].tap()
        snapshot("06_Curriculum")
        navigateBack(in: app)

        // 07 Exam detail
        XCTAssertTrue(app.buttons["feature_exam"].waitForExistence(timeout: 3))
        app.buttons["feature_exam"].tap()
        snapshot("07_Exam")
        navigateBack(in: app)

        // 08 Score detail
        XCTAssertTrue(app.buttons["feature_score"].waitForExistence(timeout: 3))
        app.buttons["feature_score"].tap()
        snapshot("08_Score")
        navigateBack(in: app)

        // 09 Feed (tab index 2)
        selectTab("Discover", index: 2, in: app)
        if !app.buttons["discover_feed"].exists {
            navigateBack(in: app)
        }
        app.buttons["discover_feed"].tap()
        snapshot("09_Feed")
    }
}

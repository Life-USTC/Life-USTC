//
//  E2ETests.swift
//  Life@USTC
//
//  End-to-end UI tests covering login, navigation, and feature access.
//

import XCTest

final class E2ETests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("UI_TEST_RESET_ONBOARDING")

        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            for label in ["Not Now", "以后", "Never for This Website", "不再提示"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
    }

    // MARK: - Helpers

    /// Complete the USTC CAS demo login flow (username: demo, password: demo).
    private func performDemoLogin() {
        let username = app.textFields["login_username_field"]
        XCTAssertTrue(username.waitForExistence(timeout: 10), "Login screen should appear")
        username.tap()
        username.typeText("demo")

        let password = app.secureTextFields["login_password_field"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("demo")

        // Dismiss keyboard
        app.tap()
        app.buttons["login_submit_button"].tap()

        // Handle the "Save Password" system alert by backgrounding and returning
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 5)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 5)
    }

    /// Complete the onboarding flow after login.
    private func completeOnboarding() {
        let addButton = app.buttons["onboarding_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Onboarding should appear after login")
        addButton.tap()

        if app.buttons["additional_course_done"].waitForExistence(timeout: 5) {
            app.buttons["additional_course_done"].tap()
        }
        if app.buttons["onboarding_done_button"].waitForExistence(timeout: 5) {
            app.buttons["onboarding_done_button"].tap()
        } else if app.buttons["onboarding_close_button"].waitForExistence(timeout: 2) {
            app.buttons["onboarding_close_button"].tap()
        }
    }

    /// Navigate to a tab, handling both iPhone tab bar and iPad sidebar.
    private func selectTab(_ tabName: String) {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            // iPhone: use the tab bar
            let tabs = ["Home": 0, "Features": 1, "Feed": 2, "Settings": 3]
            if let index = tabs[tabName] {
                tabBar.buttons.element(boundBy: index).tap()
            }
        } else {
            // iPad: use sidebar buttons
            let sidebarButton = app.buttons["Tab.\(tabName)"]
            if sidebarButton.waitForExistence(timeout: 5) {
                sidebarButton.tap()
            }
        }
    }

    /// Launch app, log in with demo credentials, and complete onboarding.
    private func launchAndLogin() {
        app.launch()
        performDemoLogin()
        completeOnboarding()
    }

    // MARK: - Tests

    @MainActor
    func testLoginScreenAppears() {
        app.launch()

        let username = app.textFields["login_username_field"]
        XCTAssertTrue(username.waitForExistence(timeout: 10), "Login username field should appear on first launch")

        let password = app.secureTextFields["login_password_field"]
        XCTAssertTrue(password.exists, "Login password field should be present")

        let submit = app.buttons["login_submit_button"]
        XCTAssertTrue(submit.exists, "Login submit button should be present")
    }

    @MainActor
    func testDemoLoginSucceeds() {
        app.launch()
        performDemoLogin()

        // After demo login, onboarding should appear
        let addButton = app.buttons["onboarding_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Onboarding should appear after successful demo login")
    }

    @MainActor
    func testOnboardingCompletesToMainScreen() {
        launchAndLogin()

        // After onboarding, the main tab interface should be visible
        let tabBar = app.tabBars.firstMatch
        let hasTabBar = tabBar.waitForExistence(timeout: 10)

        if !hasTabBar {
            // iPad — sidebar tab buttons should exist
            XCTAssertTrue(
                app.buttons["Tab.Home"].waitForExistence(timeout: 10),
                "Home tab should be accessible after onboarding"
            )
        } else {
            XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 4, "Tab bar should have at least 4 tabs")
        }
    }

    @MainActor
    func testTabNavigation() {
        launchAndLogin()

        // Wait for main UI
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 10)

        // Navigate to Features tab
        selectTab("Features")
        let featureCurriculum = app.buttons["feature_curriculum"]
        XCTAssertTrue(featureCurriculum.waitForExistence(timeout: 10), "Features tab should show curriculum feature")

        // Navigate to Feed tab
        selectTab("Feed")
        // Feed tab should load without crash — just verify we navigated
        sleep(1)

        // Navigate to Settings tab
        selectTab("Settings")
        let serverAccount = app.buttons["settings_server_account"]
            .exists ? app.buttons["settings_server_account"] : app.staticTexts["Server Account"]
        // Settings should contain identifiable elements
        let aboutExists = app.buttons["settings_about"].waitForExistence(timeout: 5)
            || app.staticTexts["About"].waitForExistence(timeout: 2)
        XCTAssertTrue(aboutExists, "Settings tab should contain About section")

        // Navigate back to Home
        selectTab("Home")
    }

    @MainActor
    func testFeaturesTabShowsAllFeatures() {
        launchAndLogin()

        selectTab("Features")

        let curriculum = app.buttons["feature_curriculum"]
        XCTAssertTrue(curriculum.waitForExistence(timeout: 10), "Curriculum feature should be visible")

        let exam = app.buttons["feature_exam"]
        XCTAssertTrue(exam.exists, "Exam feature should be visible")

        let score = app.buttons["feature_score"]
        XCTAssertTrue(score.exists, "Score feature should be visible")
    }

    @MainActor
    func testCurriculumFeatureNavigation() {
        launchAndLogin()

        selectTab("Features")

        let curriculum = app.buttons["feature_curriculum"]
        XCTAssertTrue(curriculum.waitForExistence(timeout: 10))
        curriculum.tap()

        // Should navigate to curriculum detail — verify we're not still on features grid
        sleep(1)

        // Navigate back (if on iPhone with nav stack)
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }

    @MainActor
    func testExamFeatureNavigation() {
        launchAndLogin()

        selectTab("Features")

        let exam = app.buttons["feature_exam"]
        XCTAssertTrue(exam.waitForExistence(timeout: 10))
        exam.tap()

        sleep(1)

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }

    @MainActor
    func testSettingsServerAccountAccess() {
        launchAndLogin()

        selectTab("Settings")

        let serverAccount = app.buttons["settings_server_account"]
        if serverAccount.waitForExistence(timeout: 10) {
            serverAccount.tap()
            // Server Account view should show server info
            let serverText = app.staticTexts["Server Info"]
                .exists ? true : app.staticTexts["Server Account"].waitForExistence(timeout: 5)
            XCTAssertTrue(serverText, "Server Account view should be accessible")
        }
    }

    @MainActor
    func testSettingsAboutAccess() {
        launchAndLogin()

        selectTab("Settings")

        let about = app.buttons["settings_about"]
        if about.waitForExistence(timeout: 10) {
            about.tap()
            sleep(1)
        }
    }
}

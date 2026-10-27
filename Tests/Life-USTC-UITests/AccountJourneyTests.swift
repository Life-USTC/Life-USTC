import XCTest

final class AccountJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, accountJourney: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "UI_TEST_SKIP_ONBOARDING"]
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let requests = XCTAttachment(string: fixture.requests.map { "\($0.method) \($0.path) \($0.query)" }.joined(separator: "\n"))
            requests.lifetime = .keepAlways
            add(requests)
        }
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testAccountManagementOpensSupportedWebsitePagesAndRefreshesProfileOnReturn() throws {
        launchAccount()
        capture("Settings")
        try open("settings_server_account")
        capture("ServerAccount")
        try open("server_account_management")
        assertText("These settings open the Life@USTC website.")
        capture("AccountManagement")
        let pages = [("profile", "/account/settings/profile"), ("preferences", "/account/settings/preferences"),
                     ("accounts", "/account/settings/accounts"), ("security", "/account/settings/security"),
                     ("authorizations", "/account/settings/authorizations"), ("administration", "/admin"),
                     ("danger", "/account/settings/danger")]
        for (id, path) in pages {
            let previousReads = requestCount("GET", "/api/account/profile")
            try open("account_web_\(id)")
            waitForRequest("GET", path, timeout: 45)
            let request = try XCTUnwrap(fixture.requests.last { $0.path == path })
            XCTAssertNil(request.headers["authorization"], "Website must authenticate its own session")
            closeWebsite()
            waitUntil { self.requestCount("GET", "/api/account/profile") > previousReads }
        }
        back()
        assertText("Updated Fixture Student")
    }

    @MainActor
    func testActivityPaginationFailureRetainsHistoryAndRetriesTheSameCursor() throws {
        launchAccount()
        try open("settings_account_management")
        try open("account_app_activity")
        waitForRequest("GET", "/api/account/client-activity", query: ["limit": "30"])
        assertText("Comment posted")
        assertText("Succeeded")
        fixture.failNextRequest(method: "GET", path: "/api/account/client-activity")
        try open("account_activity_load_more")
        assertText("Workspace fixture unavailable")
        assertText("Comment posted")
        try open("Retry")
        assertText("File deleted")
        assertText("Denied")
        assertText("Comment posted")
        XCTAssertFalse(app.buttons["account_activity_load_more"].exists)
        let pages = fixture.requests.filter { $0.path == "/api/account/client-activity" }
        XCTAssertEqual(pages.count, 3)
        XCTAssertNil(pages[0].query["cursor"])
        XCTAssertEqual(pages[1].query["cursor"], AccountJourneyHTTPState.cursor)
        XCTAssertEqual(pages[2].query["cursor"], AccountJourneyHTTPState.cursor)
        XCTAssertTrue(pages.allSatisfy { $0.headers["authorization"] == "Bearer \(ServerJourneyHTTPFixture.token)" })
        capture("AccountActivity")
    }

    @MainActor
    func testSignedOutAccountDoesNotReadPrivateAppActivity() throws {
        app.launchEnvironment.removeValue(forKey: "UI_TEST_SERVER_ACCESS_TOKEN")
        launchAccount()
        assertText("Not signed in")
        XCTAssertFalse(app.buttons["settings_account_management"].exists)
        XCTAssertFalse(fixture.requests.contains { $0.path == "/api/account/client-activity" })
    }

    @MainActor
    private func launchAccount() {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        } else {
            let tab = app.buttons["Tab.Account"]
            if !tab.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 10))
                toggle.tap()
            }
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }
        XCTAssertTrue(app.buttons["settings_account_management"].waitForExistence(timeout: 3)
                      || app.otherElements["settings_server_account"].exists
                      || app.staticTexts["Not signed in"].exists)
    }

    @MainActor
    private func closeWebsite() {
        let done = app.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "Close", "完成", "关闭"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "BrowserView")).firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil { !browser.exists }
        XCTAssertTrue(app.navigationBars["Account Management"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m5-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private enum InteractionFailure: Error {
        case unavailableControl
    }

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let button = app.buttons.matching(identifier: id).firstMatch
        _ = button.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeDown()
        }
        guard button.waitForExistence(timeout: 10) else {
            XCTFail("Missing control: \(id)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
        let condition = NSPredicate(format: "enabled == true AND hittable == true")
        if !condition.evaluate(with: button) {
            let ready = XCTNSPredicateExpectation(predicate: condition, object: button)
            guard XCTWaiter.wait(for: [ready], timeout: 10) == .completed else {
                XCTFail("Unavailable control: \(id)", file: file, line: line)
                throw InteractionFailure.unavailableControl
            }
        }
        button.tap()
    }

    @MainActor
    private func assertText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        for _ in 0..<6 {
            if element.exists && element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing text: \(text)", file: file, line: line)
    }

    @MainActor
    private func back() {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    private func requestCount(_ method: String, _ path: String) -> Int {
        fixture.requests.filter { $0.method == method && $0.path == path }.count
    }

    private func waitForRequest(_ method: String, _ path: String, query: [String: String] = [:], timeout: TimeInterval = 10) {
        waitUntil(timeout: timeout) {
            self.fixture.requests.contains { request in
                request.method == method && request.path == path && query.allSatisfy { request.query[$0.key] == $0.value }
            }
        }
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }
}

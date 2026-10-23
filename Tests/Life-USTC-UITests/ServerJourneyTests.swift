import XCTest

/// Native UI + HTTP-fixture integration. These tests do not verify production
/// OAuth registration, server ownership enforcement, or the campus systems.
final class ServerJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "UI_TEST_SKIP_ONBOARDING"]
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app?.terminate()
        fixture?.stop()
        app = nil
        fixture = nil
    }

    @MainActor
    func testAnonymousCatalogSearchAndDetailWithoutCAS() throws {
        app.launch()
        open("home_catalog")
        XCTAssertFalse(app.textFields["login_username_field"].exists)

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Calculus")
        waitForRequest(method: "GET", path: "/api/catalog/sections", query: ["search": "Calculus"])

        let section = app.buttons["catalog_section_42"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        section.tap()
        XCTAssertTrue(app.staticTexts["MATH101.01"].firstMatch.waitForExistence(timeout: 10))
        waitForRequest(method: "GET", path: "/api/catalog/sections/42")
        XCTAssertFalse(fixture.requests.contains { $0.headers["authorization"] != nil })
        XCTAssertFalse(fixture.requests.contains { $0.method != "GET" })
    }

    @MainActor
    func testAnonymousCourseAndTeacherDetailsReachTeachingSections() throws {
        app.launch()
        open("home_catalog")
        let catalog = app.segmentedControls["catalog_kind"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 10))
        catalog.buttons["Courses"].tap()
        open("catalog_course_1001")
        waitForRequest(method: "GET", path: "/api/catalog/courses/1001")
        waitForRequest(method: "GET", path: "/api/catalog/sections", query: ["courseId": "11", "page": "1", "pageSize": "100"])
        open("catalog_section_42")
        XCTAssertTrue(app.buttons["section_sign_in"].waitForExistence(timeout: 10))
        waitForRequest(method: "GET", path: "/api/catalog/sections/42")

        returnHome()
        open("home_catalog")
        XCTAssertTrue(catalog.waitForExistence(timeout: 10))
        catalog.buttons["Teachers"].tap()
        open("catalog_teacher_3")
        waitForRequest(method: "GET", path: "/api/catalog/teachers/3")
        waitForRequest(method: "GET", path: "/api/catalog/sections", query: ["teacherId": "3", "page": "1", "pageSize": "100"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Professor"))
            .firstMatch.waitForExistence(timeout: 10))
        open("catalog_section_43")
        XCTAssertTrue(app.buttons["section_sign_in"].waitForExistence(timeout: 10))
        waitForRequest(method: "GET", path: "/api/catalog/sections/43")

        XCTAssertFalse(app.textFields["login_username_field"].exists)
        XCTAssertFalse(fixture.requests.contains { $0.headers["authorization"] != nil })
        XCTAssertFalse(fixture.requests.contains { $0.path.hasPrefix("/api/workspace/") })
        XCTAssertTrue(fixture.requests.allSatisfy { $0.method == "GET" })
    }

    @MainActor
    func testSectionDetailsShowScheduleAndKeepUndatedExam() throws {
        app.launch()
        open("home_catalog")
        open("catalog_section_42")
        XCTAssertTrue(app.buttons["section_sign_in"].waitForExistence(timeout: 10))
        waitForRequest(method: "GET", path: "/api/catalog/sections/42/schedules", query: ["page": "1", "pageSize": "100"])

        assertVisibleText("08:15 – 09:45")
        assertVisibleText("East Campus 2201")
        assertVisibleText("2026-12-23")
        assertVisibleText("09:00 – 11:00")
        assertVisibleText("Exam Hall 1")
        assertVisibleText("Date unavailable")
        assertVisibleText("Exam Hall 2")
        XCTAssertFalse(app.staticTexts["No published exams"].exists)
        XCTAssertFalse(fixture.requests.contains { $0.path.hasPrefix("/api/workspace/") })
    }

    @MainActor
    func testSectionCommentsUseInternalTargetID() throws {
        app.launch()
        open("home_catalog")
        open("catalog_section_42")
        assertVisibleText("Comments")
        open("Comments")
        XCTAssertTrue(app.staticTexts["No Comments"].waitForExistence(timeout: 10))
        waitForRequest(method: "GET", path: "/api/community/comments", query: ["targetType": "section", "targetId": "7"])
        let request = try XCTUnwrap(fixture.requests.first { $0.path == "/api/community/comments" })
        XCTAssertNil(request.query["sectionId"])
    }

    @MainActor
    func testSubscriptionKindAndRemovalPreserveAnotherMembership() throws {
        launchSignedIn()
        open("home_catalog")
        open("catalog_section_42")
        open("section_subscribe")
        XCTAssertTrue(app.buttons["section_unsubscribe"].waitForExistence(timeout: 10))

        let added = try XCTUnwrap(fixture.requests.first {
            $0.method == "PATCH" && $0.path == "/api/workspace/subscriptions"
        })
        XCTAssertEqual(added.jsonBody["sectionIds"] as? [Int], [7])
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant"])

        returnHome()
        open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscription_42"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["subscription_43"].exists)
        open("subscription_kind_42")
        open("subscription_kind_auditor")
        waitForRequest(method: "PATCH", path: "/api/workspace/subscriptions/42")
        XCTAssertEqual(fixture.subscriptionKinds, [42: "auditor", 43: "teaching_assistant"])

        open("subscription_42")
        open("section_unsubscribe")
        XCTAssertTrue(app.buttons["section_subscribe"].waitForExistence(timeout: 10))
        let removed = try XCTUnwrap(fixture.requests.first {
            $0.method == "DELETE" && $0.path == "/api/workspace/subscriptions"
        })
        XCTAssertEqual(removed.jsonBody["sectionIds"] as? [Int], [7])
        XCTAssertEqual(fixture.subscriptionKinds, [43: "teaching_assistant"])
        XCTAssertFalse(fixture.requests.contains { $0.method == "POST" && $0.path == "/api/workspace/subscriptions" })
    }

    @MainActor
    func testCalendarDisplaysServerDatedEvent() throws {
        launchSignedIn()
        open("home_calendar")
        XCTAssertTrue(app.staticTexts["Server-dated seminar"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["East Campus 2201"].exists)
        let request = try XCTUnwrap(fixture.requests.first { $0.path == "/api/workspace/calendar/events" })
        XCTAssertNotNil(request.query["dateFrom"])
        XCTAssertNotNil(request.query["dateTo"])
        XCTAssertEqual(request.query["page"], "1")
        XCTAssertEqual(request.headers["authorization"], "Bearer \(ServerJourneyHTTPFixture.token)")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "8:15")).firstMatch.exists)
    }

    @MainActor
    func testFailedCatalogReadCanBeRetried() throws {
        fixture.failNextCatalogRead()
        app.launch()
        open("home_catalog")
        XCTAssertTrue(app.staticTexts["Catalog fixture unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["catalog_section_42"].exists)
        open("catalog_retry")
        XCTAssertTrue(app.buttons["catalog_section_42"].waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(fixture.requests.filter { $0.path == "/api/catalog/sections" }.count, 2)
    }

    @MainActor
    func testFailedSubscriptionDoesNotReportSuccess() throws {
        fixture.failNextSubscriptionWrite()
        launchSignedIn()
        open("home_catalog")
        open("catalog_section_42")
        open("section_subscribe")
        XCTAssertTrue(app.staticTexts["Subscription fixture unavailable"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["section_subscribe"].exists)
        XCTAssertFalse(app.buttons["section_unsubscribe"].exists)
        XCTAssertEqual(fixture.subscriptionKinds, [43: "teaching_assistant"])

        open("section_subscribe")
        XCTAssertTrue(app.buttons["section_unsubscribe"].waitForExistence(timeout: 10))
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant"])
    }

    @MainActor
    func testSignOutRemovesPreviouslyVisibleSubscriptions() throws {
        launchSignedIn()
        open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscription_43"].waitForExistence(timeout: 10))

        selectTab("Account", index: 3)
        open("settings_server_account")
        open("Sign Out")
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 10))
        let readsAfterSignOut = fixture.requests.filter { $0.path == "/api/workspace/subscriptions/current" }.count

        selectTab("Home", index: 0)
        if app.buttons["home_subscriptions"].exists { open("home_subscriptions") }
        XCTAssertTrue(app.buttons["subscriptions_sign_in"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["subscription_43"].exists)
        XCTAssertEqual(
            fixture.requests.filter { $0.path == "/api/workspace/subscriptions/current" }.count,
            readsAfterSignOut
        )
    }

    @MainActor
    private func launchSignedIn() {
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token
        app.launch()
    }

    @MainActor
    private func open(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier]
        _ = button.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(identifier)", file: file, line: line)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed,
                       "Control did not become available: \(identifier)", file: file, line: line)
        button.tap()
    }

    @MainActor
    private func assertVisibleText(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let text = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        for _ in 0..<6 {
            if text.exists && text.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Missing detail: \(label)", file: file, line: line)
        XCTAssertTrue(text.isHittable, "Detail is not visible: \(label)", file: file, line: line)
    }

    @MainActor
    private func returnHome() {
        for _ in 0..<3 {
            if app.navigationBars["Life@USTC"].exists { return }
            let back = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
        }
        XCTAssertTrue(app.navigationBars["Life@USTC"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectTab(_ name: String, index: Int) {
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: index).tap()
        } else {
            if !app.buttons["Tab.\(name)"].isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Sidebar should be available")
                toggle.tap()
            }
            open("Tab.\(name)")
        }
    }

    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    private func waitForRequest(method: String, path: String, query: [String: String] = [:]) {
        let predicate = NSPredicate { [weak self] _, _ in
            self?.fixture.requests.contains { request in
                request.method == method && request.path == path
                    && query.allSatisfy { request.query[$0.key] == $0.value }
            } ?? false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
}

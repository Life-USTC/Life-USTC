import XCTest

final class ParityNavigationJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let sidebarLabels = ["Show Sidebar", "Toggle Sidebar", "Hide Sidebar"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, community: true, catalogHistory: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "UI_TEST_SKIP_ONBOARDING"]
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            for attachment in [XCTAttachment(screenshot: XCUIScreen.main.screenshot()),
                               XCTAttachment(string: app.debugDescription),
                               XCTAttachment(string: fixture.requests.map { "\($0.method) \($0.path) \($0.query)" }.joined(separator: "\n"))] {
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testWeekAgendaTodayAndSemesterUseVisibleDateRanges() async throws {
        app.launch()
        try await open("home_calendar")
        waitUntil { self.fixture.requests.contains { $0.path == "/api/workspace/calendar/events" } }
        let first = try XCTUnwrap(fixture.requests.last { $0.path == "/api/workspace/calendar/events" })
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        let start = try XCTUnwrap(formatter.date(from: String(try XCTUnwrap(first.query["dateFrom"]).prefix(10))))
        XCTAssertEqual(calendar.component(.weekday, from: start), 2)
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let header = app.staticTexts["calendar_day_\(formatter.string(from: day))"]
            reveal(header)
            XCTAssertTrue(header.exists, "The week agenda retains all seven day headings")
        }
        let originalRange = app.staticTexts["calendar_range"].label
        try await open("Previous period")
        waitUntil { self.app.staticTexts["calendar_range"].label != originalRange }
        try await open("calendar_today")
        waitUntil { self.app.staticTexts["calendar_range"].label == originalRange }
        let mode = app.segmentedControls["workspace_calendar_mode"]
        XCTAssertTrue(mode.buttons["Semester"].waitForExistence(timeout: 10))
        mode.buttons["Semester"].tap()
        try await open("calendar_semester")
        try await open("Spring 2026")
        waitUntil {
            self.fixture.requests.contains {
                $0.path == "/api/workspace/calendar/events"
                    && $0.query["dateFrom"]?.hasPrefix("2026-02-01") == true
                    && $0.query["dateTo"]?.hasPrefix("2026-07-31") == true
            }
        }
        XCTAssertEqual(app.staticTexts["calendar_range"].label, "2026-02-01 – 2026-07-31")
        capture("SemesterCalendar")
        try await open("calendar_today")
        waitUntil { self.app.staticTexts["calendar_range"].label != "2026-02-01 – 2026-07-31" }
    }

    @MainActor
    func testSectionCalendarCopyAndShareRetainPublicJWIdentity() async throws {
        app.launch()
        try await open("home_catalog")
        try await open("catalog_section_42")
        try await open("section_calendar_export")
        XCTAssertTrue(app.navigationBars["Teaching Section Calendar"].waitForExistence(timeout: 10))
        try await open("section_calendar_copy")
        XCTAssertTrue(app.buttons["section_calendar_copy"].label.contains("Copied"))
        try await open("section_calendar_share")
        assertShareSheet()
        capture("SectionCalendarShare")
        XCTAssertFalse(fixture.requests.contains { $0.method != "GET" })
    }

    @MainActor
    func testCombinedCalendarSelectionAndCourseSharing() async throws {
        app.launch()
        try await open("home_subscriptions")
        try await open("subscriptions_calendar_export")
        XCTAssertFalse(app.buttons["section_calendar_copy"].exists)
        selectCalendarSection(7)
        selectCalendarSection(8)
        try await open("section_calendar_copy")
        XCTAssertTrue(app.buttons["section_calendar_copy"].label.contains("Copied"))
        capture("CombinedCalendar")
        back()
        back()
        try await open("home_catalog")
        app.segmentedControls["catalog_kind"].buttons["Courses"].tap()
        try await open("catalog_course_1001")
        try await open("share_content")
        assertShareSheet()
        capture("CourseShare")
    }

    @MainActor
    func testSectionHomeworkGuideCollapsesAndDoesNotRestrictTheTitle() async throws {
        app.launch()
        try await open("home_catalog")
        try await open("catalog_section_42")
        try await open("Shared Homework")
        try await open("section.homeworks.create")
        try await open("homework.editor.guide")
        XCTAssertTrue(app.staticTexts["These are suggestions and do not prevent saving."].waitForExistence(timeout: 10))
        capture("HomeworkGuide")
        try await open("homework.editor.guide")
        let title = app.textFields["homework.editor.title"]
        reveal(title)
        title.tap()
        title.typeText("Prepare a worked example")
        try await open("homework.editor.save")
        waitUntil {
            self.fixture.requests.contains {
                $0.method == "POST" && $0.path == "/api/community/section-homeworks"
                    && $0.jsonBody["title"] as? String == "Prepare a worked example"
            }
        }
        let created = try XCTUnwrap(fixture.communityHomeworks.first { $0["title"] as? String == "Prepare a worked example" })
        let id = try XCTUnwrap(created["id"] as? String)
        try await open(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                             "section.homeworks.row.\(id)", "Homework actions")).firstMatch)
        try await open("Edit")
        try await open("homework.editor.guide")
        XCTAssertTrue(app.staticTexts["These are suggestions and do not prevent saving."].waitForExistence(timeout: 10))
        try await open("homework.editor.guide")
        XCTAssertTrue(app.buttons["homework.editor.save"].exists)
    }

    @MainActor
    func testUsageGuideOpensTheWebsiteWithoutNativeBearerCredentials() async throws {
        app.launch()
        selectAccount()
        try await open("Help and Guides")
        for path in ["usage/mobile", "usage/bot", "usage/mcp", "usage/cli", "guides/markdown-support", "community/comments/guide"] {
            let link = app.descendants(matching: .any).matching(identifier: "guide_\(path)").firstMatch
            reveal(link)
            XCTAssertTrue(link.exists)
        }
        capture("HelpGuides")
        try await open(app.descendants(matching: .any).matching(identifier: "guide_usage/mobile").firstMatch)
        waitUntil(timeout: 30) { self.fixture.requests.contains { $0.path == "/usage/mobile" } }
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/usage/mobile" })
        XCTAssertNil(request.headers["authorization"])
        app.activate()
        XCTAssertTrue(app.navigationBars["Help and Guides"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func assertShareSheet() {
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let copy = sheet.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", ["Copy", "Copy Link"])).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "The system share sheet exposes copying the public URL")
    }

    @MainActor
    private func selectCalendarSection(_ id: Int) {
        let row = app.switches["calendar_export_section_\(id)"]
        reveal(row)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let control = row.switches.firstMatch
        (control.exists ? control : row).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }

    @MainActor
    private func selectAccount() {
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: 3).tap()
        } else {
            let tab = app.buttons["Tab.Account"]
            if !tab.isHittable {
                app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch.tap()
            }
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
    }

    private enum InteractionFailure: Error {
        case unavailableControl
    }

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await open(app.buttons.matching(identifier: id).firstMatch, file: file, line: line)
    }

    @MainActor
    private func open(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) async throws {
        _ = element.waitForExistence(timeout: 2)
        reveal(element)
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Missing control: \(element)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
        let condition = NSPredicate(format: "enabled == true AND hittable == true")
        if !condition.evaluate(with: element) {
            let ready = XCTNSPredicateExpectation(predicate: condition, object: element)
            guard await XCTWaiter.fulfillment(of: [ready], timeout: 10) == .completed else {
                XCTFail("Control did not satisfy enabled == true AND hittable == true: \(element)", file: file, line: line)
                throw InteractionFailure.unavailableControl
            }
        }
        element.tap()
    }

    @MainActor
    private func back() {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m6-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }
}

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
        XCTAssertEqual(calendar.component(.weekday, from: start), 1)
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
        PrimaryNavigation.select("Campus", index: 2, in: app)
        try await open("discover_catalog")
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
        PrimaryNavigation.select("Campus", index: 2, in: app)
        try await open("discover_catalog")
        app.segmentedControls["catalog_kind"].buttons["Courses"].tap()
        try await open("catalog_course_1001")
        try await open("share_content")
        assertShareSheet()
        capture("CourseShare")
    }

    @MainActor
    func testSectionHomeworkGuideCollapsesAndDoesNotRestrictTheTitle() async throws {
        app.launch()
        PrimaryNavigation.select("Campus", index: 2, in: app)
        try await open("discover_catalog")
        try await open("catalog_section_42")
        try await open("Shared Homework")
        try await open("section.homeworks.create")
        try await setHomeworkGuide(expanded: true)
        XCTAssertTrue(app.staticTexts["These are suggestions and do not prevent saving."].waitForExistence(timeout: 10))
        capture("HomeworkGuide")
        try await setHomeworkGuide(expanded: false)
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
        try await setHomeworkGuide(expanded: true)
        XCTAssertTrue(app.staticTexts["These are suggestions and do not prevent saving."].waitForExistence(timeout: 10))
        try await setHomeworkGuide(expanded: false)
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
        PrimaryNavigation.openAccount("settings", in: app)
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
        try await waitFor(element, predicate: "enabled == true AND hittable == true", file: file, line: line)
        element.tap()
    }

    private enum InteractionFailure: Error {
        case unavailableControl
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, predicate: String,
                         file: StaticString = #filePath, line: UInt = #line) async throws {
        let condition = NSPredicate(format: predicate)
        // Accessibility snapshots can outlast the polling deadline even when ready.
        if condition.evaluate(with: element) { return }
        let expectation = XCTNSPredicateExpectation(predicate: condition, object: element)
        guard await XCTWaiter.fulfillment(of: [expectation], timeout: 10) == .completed else {
            XCTFail("Control did not satisfy \(predicate): \(element)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
    }

    @MainActor
    private func setHomeworkGuide(expanded: Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let guide = app.buttons["homework.editor.guide"]
        reveal(guide)
        try await waitFor(guide, predicate: "exists == true AND enabled == true AND hittable == true", file: file, line: line)
        let label = guide.staticTexts["Homework writing guide"]
        try await waitFor(label, predicate: "exists == true AND hittable == true", file: file, line: line)
        label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let explanation = app.staticTexts["These are suggestions and do not prevent saving."]
        try await waitFor(explanation, predicate: expanded ? "exists == true" : "exists == false", file: file, line: line)
    }

    @MainActor
    private func back() {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@) AND NOT (identifier IN %@)", sidebarLabels, ["account_menu", "account_destination_done"])).firstMatch
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

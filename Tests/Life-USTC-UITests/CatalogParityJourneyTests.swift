import XCTest

final class CatalogParityJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, catalogHistory: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "UI_TEST_SKIP_ONBOARDING"]
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let requests = XCTAttachment(string: fixture.requests.map {
                "\($0.method) \($0.path) \($0.query)"
            }.joined(separator: "\n"))
            requests.lifetime = .keepAlways
            add(requests)
        }
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testEducationLevelFilterUsesCatalogMetadataAndCanonicalID() throws {
        app.launch()
        open("home_catalog")
        app.segmentedControls["catalog_kind"].buttons["Courses"].tap()
        waitForRequest("/api/catalog/metadata")
        open("catalog_education_level")
        open("Undergraduate")
        waitForRequest("/api/catalog/courses", query: ["educationLevelId": "1"])
        XCTAssertTrue(app.buttons["catalog_course_1001"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["catalog_course_1002"].exists)
        capture("CatalogEducation")
    }

    @MainActor
    func testHistoricalCourseSectionKeepsDetailsAndExportWithoutNewSubscription() throws {
        app.launch()
        open("home_catalog")
        app.segmentedControls["catalog_kind"].buttons["Courses"].tap()
        open("catalog_course_1001")
        waitForRequest("/api/catalog/courses/1001/sections")
        open("catalog_section_44")
        waitForRequest("/api/catalog/sections/44")
        assertText("Historical section")
        assertText("Spring 2026")
        XCTAssertFalse(app.buttons["section_subscribe"].exists)
        XCTAssertFalse(app.buttons["section_sign_in"].exists)
        capture("HistoricalSection")
        let export = app.buttons["section_calendar_export"]
        reveal(export)
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        XCTAssertFalse(fixture.requests.contains { $0.method != "GET" })
    }

    @MainActor
    func testScheduleShowsWeekBuildingCampusAndLinksActualTeacher() throws {
        app.launch()
        open("home_catalog")
        open("catalog_section_42")
        assertText("Week 1")
        assertText("Teaching Building 2")
        assertText("East Campus")
        capture("Schedule")
        open("section_schedule_901_teacher_3")
        waitForRequest("/api/catalog/teachers/3")
        assertText("Professor")
    }

    @MainActor
    func testSubscriptionsGroupBySemesterAndKeepTeachersAndExportEntry() throws {
        fixture.includeHistoricalSubscription()
        app.launch()
        open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscription_42"].waitForExistence(timeout: 10))
        assertText("2026 Fall · 1")
        assertText("Spring 2026 · 2")
        XCTAssertTrue(app.buttons["subscription_43"].exists)
        assertText("Ada Teacher")
        assertText("Historical section")
        let export = app.buttons["subscriptions_calendar_export"]
        reveal(export)
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        capture("Subscriptions")
        export.tap()
        XCTAssertTrue(app.switches["calendar_export_section_7"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["calendar_export_section_9"].exists)
        open("calendar_export_historical_9")
        waitForRequest("/api/catalog/sections/44")
        open("section_calendar_export")
        XCTAssertTrue(app.navigationBars["Teaching Section Calendar"].waitForExistence(timeout: 10))
        capture("HistoricalCalendarExport")
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m6-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(identifier: id).firstMatch
        _ = button.waitForExistence(timeout: 2)
        reveal(button)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(id)", file: file, line: line)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, file: file, line: line)
        button.tap()
    }

    @MainActor
    private func assertText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        reveal(element)
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing text: \(text)", file: file, line: line)
    }

    private func waitForRequest(_ path: String, query: [String: String] = [:]) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.fixture.requests.contains { request in
                request.method == "GET" && request.path == path && query.allSatisfy { request.query[$0.key] == $0.value }
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
}

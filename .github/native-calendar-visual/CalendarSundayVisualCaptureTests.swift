import UIKit
import XCTest

/// Temporary native visual carrier, identical in both source arms. Not shipped.
final class CalendarSundayVisualCaptureTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private var config: [String: Any]!
    private var chinese: Bool { config["locale"] as? String == "zh-Hans" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "CalendarVisualConfig", withExtension: "json"))
        config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        fixture = ServerJourneyHTTPFixture(workspace: true, youngCampus: true)
        fixture.enablePublicDiscoveryFixture()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", chinese ? "(zh-Hans)" : "(en)",
                               "-AppleLocale", chinese ? "zh_CN" : "en_US", "UI_TEST_SKIP_ONBOARDING"]
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token
    }

    override func tearDownWithError() throws {
        if let fixture {
            XCTAssertTrue(fixture.requests.allSatisfy { $0.method == "GET" }, "Visual navigation must not write server state")
            var metadata = config ?? [:]
            metadata["requests"] = fixture.requests.map { ["method": $0.method, "path": $0.path, "query": $0.query] as [String: Any] }
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "native-visual-provenance"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if (testRun?.failureCount ?? 0) > 0, let app {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let image = XCTAttachment(screenshot: app.screenshot())
            image.lifetime = .keepAlways
            add(image)
        }
        app?.terminate()
        fixture?.stop()
    }

    @MainActor
    func testPersonalWeekNativeCapture() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try tap(app.buttons["home_calendar"])
        try waitUntil { self.fixture.requests.contains { $0.path == "/api/workspace/calendar/events" } }
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/api/workspace/calendar/events" })
        let key = try XCTUnwrap(request.query["dateFrom"])
        let formatter = civilFormatter()
        let start = try XCTUnwrap(formatter.date(from: String(key.prefix(10))))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        XCTAssertEqual(calendar.component(.weekday, from: start), config["expectedFirstWeekday"] as? Int)
        XCTAssertTrue(app.staticTexts["calendar_range"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["calendar_day_\(formatter.string(from: start))"].waitForExistence(timeout: 10))
        try waitUntil { !self.app.activityIndicators.firstMatch.exists }
        try capture("personal-week")
    }

    @MainActor
    func testPublicYoungWeekAndMonthNativeCapture() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try openYoung()
        try tap(app.buttons[chinese ? "活动日历" : "Activity Calendar"])
        try waitUntil {
            self.fixture.requests.contains { $0.path == "/api/catalog/young-events" && $0.query["dateFrom"] != nil }
        }
        try waitUntil { !self.app.activityIndicators.firstMatch.exists }
        try capture("public-young-week")
        let previousReads = fixture.requests.filter { $0.path == "/api/catalog/young-events" }.count
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let month = try XCTUnwrap(calendar.dateInterval(of: .month, for: Date()))
        let from = civilFormatter().string(from: month.start)
        let to = civilFormatter().string(from: calendar.date(byAdding: .day, value: -1, to: month.end)!)
        try tap(app.segmentedControls.firstMatch.buttons[chinese ? "月" : "Month"])
        try waitUntil {
            let reads = self.fixture.requests.filter { $0.path == "/api/catalog/young-events" }
            return reads.count > previousReads && reads.last?.query["dateFrom"] == from
                && reads.last?.query["dateTo"] == to && !self.app.activityIndicators.firstMatch.exists
        }
        try capture("public-young-month")
    }

    @MainActor
    func testYoungDatePickerNativeCapture() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try openYoung()
        try tap(app.buttons[chinese ? "活动" : "Activities"])
        try tap(app.buttons["young.filters"])
        let outer = app.switches["young.filters.dateRange"]
        reveal(outer)
        XCTAssertTrue(outer.waitForExistence(timeout: 10))
        let control = outer.switches.firstMatch.exists ? outer.switches.firstMatch : outer
        XCTAssertEqual(control.value as? String, "0")
        try tap(control)
        try waitUntil { outer.value as? String == "1" }
        let picker = app.datePickers["young.filters.dateFrom"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        try tap(picker.buttons.firstMatch)
        // The retained native image must be independently inspected to accept
        // the actual popup state; one tap is not itself proof the popup opened.
        try capture("young-picker-after-single-open-action")
    }

    @MainActor
    private func openYoung() throws {
        if app.tabBars.firstMatch.exists {
            try tap(app.tabBars.firstMatch.buttons.element(boundBy: 2))
        } else {
            let tab = app.buttons["Tab.Discover"]
            if !tab.isHittable {
                let labels = ["Show Sidebar", "Hide Sidebar", "Toggle Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]
                try tap(app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch)
            }
            try tap(tab)
        }
        try tap(app.buttons[chinese ? "第二课堂" : "Second Classroom"])
    }

    @MainActor
    private func tap(_ element: XCUIElement) throws {
        reveal(element)
        let exists = element.waitForExistence(timeout: 10)
        XCTAssertTrue(exists)
        guard exists else { throw CaptureFailure.unavailable }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: element)
        let result = XCTWaiter.wait(for: [ready], timeout: 10)
        XCTAssertEqual(result, .completed)
        guard result == .completed else { throw CaptureFailure.unavailable }
        element.tap()
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

    private func waitUntil(_ condition: @escaping () -> Bool) throws {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 10)
        XCTAssertEqual(result, .completed)
        guard result == .completed else { throw CaptureFailure.unavailable }
    }

    @MainActor
    private func capture(_ state: String) throws {
        let day = civilFormatter().string(from: Date())
        XCTAssertEqual(day, config["anchorCivilDay"] as? String, "A midnight-crossing pair is not matched evidence")
        guard day == (config["anchorCivilDay"] as? String) else { throw CaptureFailure.anchorChanged }
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "visual-\(state)-\(config["arm"]!)-\(config["locale"]!)"
        image.lifetime = .keepAlways
        add(image)
    }

    private func civilFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private enum CaptureFailure: Error { case unavailable, anchorChanged }
}

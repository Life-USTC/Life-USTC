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
        // The Young fixture synthesizes events from dateFrom. Use the separate
        // existing workspace handler, whose schedule:901 has a fixed timestamp.
        fixture.stop()
        fixture = ServerJourneyHTTPFixture(workspace: true)
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        config["personalFixture"] = "workspace-only-fixed-record"
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try tap(app.buttons["home_calendar"])
        try waitUntil { self.fixture.requests.contains { $0.path == "/api/workspace/calendar/events" } }
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/api/workspace/calendar/events" })
        let formatter = civilFormatter()
        let start = try XCTUnwrap(formatter.date(from: String(try XCTUnwrap(request.query["dateFrom"]).prefix(10))))
        let firstWeekday = try XCTUnwrap(config["expectedFirstWeekday"] as? Int)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        let eventDay = try XCTUnwrap(formatter.date(from: "2026-10-23"))
        let leading = (calendar.component(.weekday, from: eventDay) - firstWeekday + 7) % 7
        let selectedStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -leading, to: eventDay))
        let distance = try XCTUnwrap(calendar.dateComponents([.day], from: start, to: selectedStart).day)
        XCTAssertEqual(distance % 7, 0)
        guard distance % 7 == 0 && abs(distance / 7) <= 52 else { throw CaptureFailure.unavailable }
        let direction = distance < 0 ? -1 : 1
        var current = start
        for _ in 0..<abs(distance / 7) {
            current = try XCTUnwrap(calendar.date(byAdding: .day, value: direction * 7, to: current))
            let expected = formatter.string(from: current)
            // Each action navigates one actual period, and must produce its
            // own exact query. An unapplied action fails; it is never repeated.
            try tap(app.buttons[direction < 0 ? "Previous period" : "Next period"])
            try waitUntil {
                let last = self.fixture.requests.last { $0.path == "/api/workspace/calendar/events" }
                return String((last?.query["dateFrom"] ?? "").prefix(10)) == expected
                    && self.app.staticTexts["calendar_range"].label.hasPrefix(expected)
                    && !self.app.activityIndicators.firstMatch.exists
            }
        }
        let selected = try XCTUnwrap(fixture.requests.last { $0.path == "/api/workspace/calendar/events" })
        let selectedKey = formatter.string(from: selectedStart)
        XCTAssertEqual(String(try XCTUnwrap(selected.query["dateFrom"]).prefix(10)), selectedKey)
        XCTAssertEqual(calendar.component(.weekday, from: selectedStart), firstWeekday)
        let firstHeader = app.staticTexts["calendar_day_\(selectedKey)"]
        XCTAssertTrue(firstHeader.waitForExistence(timeout: 10))
        let headerFormatter = DateFormatter()
        headerFormatter.calendar = calendar
        headerFormatter.timeZone = formatter.timeZone
        headerFormatter.locale = Locale(identifier: chinese ? "zh_CN" : "en_US")
        headerFormatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        XCTAssertEqual(firstHeader.label, headerFormatter.string(from: selectedStart))
        try waitUntil { !self.app.activityIndicators.firstMatch.exists }
        try capture("personal-fixed-week-start")

        let fixedState = WorkspaceLearningHTTPState(todoState: WorkspaceTodoHTTPState())
        let wireRequest = ServerJourneyHTTPFixture.Request(method: "GET", path: "/api/workspace/calendar/events",
            query: selected.query, headers: [:], body: Data())
        let response = try XCTUnwrap(fixedState.response(to: wireRequest))
        XCTAssertEqual(response.status, 200)
        let body = try XCTUnwrap(response.body as? [String: Any])
        let records = try XCTUnwrap(body["data"] as? [[String: Any]])
        let record = try XCTUnwrap(records.first { $0["id"] as? String == "schedule:901" })
        XCTAssertEqual(record["at"] as? String, "2026-10-23T08:15:00+08:00")
        XCTAssertEqual(record["endsAt"] as? String, "2026-10-23T09:45:00+08:00")
        config["fixedRecord"] = record
        let wire = XCTAttachment(data: try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        wire.name = "fixed-workspace-handler-response"
        wire.lifetime = .keepAlways
        add(wire)
        let card = app.buttons["workspace_event_schedule:901"]
        reveal(card)
        try waitUntil { card.exists && card.isHittable }
        let timestamp = "2026-10-23 08:15 – 2026-10-23 09:45"
        XCTAssertTrue(card.label.contains("Server-dated seminar") || card.staticTexts["Server-dated seminar"].exists)
        XCTAssertTrue(card.label.contains(timestamp) || card.staticTexts[timestamp].exists)
        retainHierarchy("personal-fixed-record-visible")
        try capture("personal-fixed-record")
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
        retainHierarchy("picker-before-open-action")
        let trigger = picker.buttons.firstMatch
        let target = XCTAttachment(string: "identifier=\(trigger.identifier)\nlabel=\(trigger.label)\nvalue=\(String(describing: trigger.value))\nframe=\(trigger.frame)")
        target.name = "native-picker-opening-target"
        target.lifetime = .keepAlways
        add(target)
        try tap(trigger)
        retainHierarchy("picker-after-single-open-action")
        var grid: (labels: [String], firstWeekday: Int)?
        try waitUntil {
            grid = self.calendarGrid()
            return grid != nil
        }
        let opened = try XCTUnwrap(grid)
        if config["arm"] as? String == "after" {
            XCTAssertEqual(opened.firstWeekday, 1, "The actual native calendar grid must start Sunday")
            guard opened.firstWeekday == 1 else { throw CaptureFailure.invalidCalendarGrid }
        }
        let headers = XCTAttachment(string: "firstWeekday=\(opened.firstWeekday)\n" + opened.labels.joined(separator: " | "))
        headers.name = "native-picker-visible-weekday-headers"
        headers.lifetime = .keepAlways
        add(headers)
        try capture("young-picker-open-calendar-grid")
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

    @MainActor
    private func retainHierarchy(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Require a real date-cell grid and one complete visible weekday-header
    /// row. Derive labels from the explicit test locale instead of assuming
    /// whether this iOS release uses narrow, short or full weekday symbols.
    @MainActor
    private func calendarGrid() -> (labels: [String], firstWeekday: Int)? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: chinese ? "zh_CN" : "en_US")
        let symbolSets: [[String]] = [formatter.veryShortStandaloneWeekdaySymbols,
                                     formatter.shortStandaloneWeekdaySymbols,
                                     formatter.standaloneWeekdaySymbols]
        let allowed = Set(symbolSets.flatMap { $0 })
        let candidates = app.staticTexts.matching(NSPredicate(format: "label IN %@", Array(allowed)))
            .allElementsBoundByIndex.compactMap { element -> (label: String, frame: CGRect)? in
                guard element.exists else { return nil }
                let frame = element.frame
                guard !frame.isEmpty && frame.intersects(app.frame) else { return nil }
                return (element.label, frame)
            }
        // The original filter sheet has two date-value buttons; a real month
        // grid supplies at least 28 date buttons. A focused value is insufficient.
        guard app.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*[0-9].*")).count >= 28 else { return nil }
        for candidate in candidates {
            let row = candidates.filter { abs($0.frame.midY - candidate.frame.midY) < 6 }
                .sorted { $0.frame.midX < $1.frame.midX }.map { $0.label }
            guard row.count == 7 else { continue }
            for symbols in symbolSets where symbols.count == 7 {
                for offset in 0..<7 {
                    let expected = Array(symbols[offset..<7]) + Array(symbols[0..<offset])
                    if row == expected { return (row, offset + 1) }
                }
            }
        }
        return nil
    }

    private enum CaptureFailure: Error { case unavailable, anchorChanged, invalidCalendarGrid }
}

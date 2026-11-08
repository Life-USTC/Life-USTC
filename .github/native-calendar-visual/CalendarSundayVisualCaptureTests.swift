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
        config["responseEvidence"] = "Deterministic routed-handler reconstruction using the actual observed app query; not a captured HTTP response"
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
            try tap(app.buttons[periodLabel(direction)])
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
        wire.name = "reconstructed-workspace-handler-response"
        wire.lifetime = .keepAlways
        add(wire)
        let card = app.buttons["workspace_event_schedule:901"]
        let timestamp = "2026-10-23 08:15 – 2026-10-23 09:45"
        try revealReadablePersonalRecord(card, title: "Server-dated seminar", timestamp: timestamp)
        XCTAssertTrue(card.label.contains("Server-dated seminar") || card.staticTexts["Server-dated seminar"].exists)
        XCTAssertTrue(card.label.contains(timestamp) || card.staticTexts[timestamp].exists)
        retainHierarchy("personal-fixed-record-visible")
        try capture("personal-fixed-record")
    }

    @MainActor
    func testPublicYoungWeekAndMonthNativeCapture() throws {
        config["publicFixture"] = PublicDiscoveryHTTPState.calendarVisualFixtureID
        config["responseEvidence"] = "Deterministic routed-handler reconstruction using the actual observed app query; not a captured HTTP response"
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        try openYoung()
        try tap(app.buttons[chinese ? "活动日历" : "Activity Calendar"])
        try waitUntil {
            self.fixture.requests.contains { $0.path == "/api/catalog/young-events" && $0.query["dateFrom"] != nil }
        }
        let first = try XCTUnwrap(fixture.requests.last { $0.path == "/api/catalog/young-events" && $0.query["dateFrom"] != nil })
        let formatter = civilFormatter()
        let initial = try XCTUnwrap(formatter.date(from: String(try XCTUnwrap(first.query["dateFrom"]).prefix(10))))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        let eventDay = try XCTUnwrap(formatter.date(from: "2026-10-23"))
        let selected = try XCTUnwrap(calendar.date(byAdding: .day, value: 1 - calendar.component(.weekday, from: eventDay), to: eventDay))
        let distance = try XCTUnwrap(calendar.dateComponents([.day], from: initial, to: selected).day)
        XCTAssertEqual(distance % 7, 0)
        guard distance % 7 == 0 && abs(distance / 7) <= 52 else { throw CaptureFailure.unavailable }
        let direction = distance < 0 ? -1 : 1
        var current = initial
        for _ in 0..<abs(distance / 7) {
            current = try XCTUnwrap(calendar.date(byAdding: .day, value: direction * 7, to: current))
            let expected = formatter.string(from: current)
            try tap(app.buttons[periodLabel(direction)])
            try waitUntil {
                let last = self.fixture.requests.last { $0.path == "/api/catalog/young-events" && $0.query["dateFrom"] != nil }
                return String((last?.query["dateFrom"] ?? "").prefix(10)) == expected
                    && !self.app.activityIndicators.firstMatch.exists
            }
        }
        XCTAssertEqual(calendar.component(.weekday, from: selected), 1)
        let weekHeader = DateFormatter()
        weekHeader.calendar = calendar
        weekHeader.timeZone = formatter.timeZone
        weekHeader.locale = Locale(identifier: "zh_CN")
        weekHeader.dateFormat = "M月d日 EEEE"
        XCTAssertTrue(app.staticTexts[weekHeader.string(from: selected)].waitForExistence(timeout: 10))
        try capture("public-fixed-week-start")
        try retainFixedPublicResponse("week")
        try revealAndAssertFixedPublicCard()
        try capture("public-fixed-week-record")

        let previousReads = fixture.requests.filter { $0.path == "/api/catalog/young-events" }.count
        let month = try XCTUnwrap(calendar.dateInterval(of: .month, for: eventDay))
        let from = formatter.string(from: month.start)
        let to = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: month.end)!)
        try tap(app.segmentedControls.firstMatch.buttons[chinese ? "月" : "Month"])
        try waitUntil {
            let reads = self.fixture.requests.filter { $0.path == "/api/catalog/young-events" }
            return reads.count > previousReads && reads.last?.query["dateFrom"] == from
                && reads.last?.query["dateTo"] == to && !self.app.activityIndicators.firstMatch.exists
        }
        var grid: (labels: [String], firstWeekday: Int)?
        try waitUntil { grid = self.calendarGrid(); return grid != nil }
        XCTAssertEqual(try XCTUnwrap(grid).firstWeekday, 1)
        try tap(app.buttons["23"].firstMatch)
        try retainFixedPublicResponse("month")
        try revealAndAssertFixedPublicCard()
        try capture("public-fixed-month-record")
    }

    @MainActor
    private func revealAndAssertFixedPublicCard() throws {
        let marker = app.staticTexts["young.status.fixture-young-m4"]
        reveal(marker)
        try waitUntil { marker.exists && marker.isHittable }
        let card = app.buttons.containing(.staticText, identifier: "young.status.fixture-young-m4").firstMatch
        XCTAssertTrue(card.exists)
        let timestamp = "10月23日 09:00 – 10月23日 11:00"
        XCTAssertTrue(card.label.contains("Science Communication Workshop") || card.staticTexts["Science Communication Workshop"].exists)
        XCTAssertTrue(card.label.contains(timestamp) || card.staticTexts[timestamp].exists)
    }

    private func retainFixedPublicResponse(_ phase: String) throws {
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/api/catalog/young-events" && $0.query["dateFrom"] != nil })
        let result = try XCTUnwrap(PublicDiscoveryHTTPState().response(to: request))
        XCTAssertEqual(result.status, 200)
        let body = try XCTUnwrap(result.body as? [String: Any])
        let records = try XCTUnwrap(body["data"] as? [[String: Any]])
        let record = try XCTUnwrap(records.first { $0["youngId"] as? String == "fixture-young-m4" })
        XCTAssertEqual(record["startAt"] as? String, "2026-10-23T09:00:00+08:00")
        XCTAssertEqual(record["endAt"] as? String, "2026-10-23T11:00:00+08:00")
        config["fixedPublicRecord"] = record
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "reconstructed-public-handler-response-\(phase)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func periodLabel(_ direction: Int) -> String {
        if chinese { return direction < 0 ? "上一时间段" : "下一时间段" }
        return direction < 0 ? "Previous period" : "Next period"
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
            grid = self.nativePickerGrid()
            return grid != nil
        }
        let opened = try XCTUnwrap(grid)
        if config["arm"] as? String == "after" {
            XCTAssertEqual(opened.firstWeekday, 1, "The actual native calendar grid must start Sunday")
            guard opened.firstWeekday == 1 else { throw CaptureFailure.invalidCalendarGrid }
        }
        let headers = XCTAttachment(string: "firstWeekday=\(opened.firstWeekday)\n" + opened.labels.joined(separator: " | "))
        headers.name = "native-picker-semantic-weekday-columns"
        headers.lifetime = .keepAlways
        add(headers)
        config["pickerHeaderEvidence"] = "Decorative weekday header has no AX text; date-cell weekday semantics and seven column positions are checked. Inspect the original PNG for the drawn header text."
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

    /// A combined card can report hittable while its text is behind the tab bar.
    /// Scroll the real list until both original labels fit its unobscured area.
    @MainActor
    private func revealReadablePersonalRecord(_ card: XCUIElement, title: String, timestamp: String) throws {
        let list = app.collectionViews.firstMatch
        let titleLabel = card.staticTexts[title]
        let timeLabel = card.staticTexts[timestamp]
        let dayHeader = list.staticTexts["calendar_day_\(String(timestamp.prefix(10)))"]
        let deadline = Date().addingTimeInterval(10)
        // Cache each original attribute once per inspection; all original
        // title/time and unobscured viewport conditions remain required.
        func inspection() -> (readable: Bool, listFrame: CGRect, viewport: CGRect, content: CGRect) {
            guard list.exists else { return (false, .zero, .zero, .zero) }
            let titleExists = titleLabel.exists
            let timeExists = timeLabel.exists
            let titleFrame = titleExists ? titleLabel.frame : .zero
            let timeFrame = timeExists ? timeLabel.frame : .zero
            func measurable(_ frame: CGRect) -> Bool {
                !frame.isEmpty && frame.minX.isFinite && frame.minY.isFinite
                    && frame.maxX.isFinite && frame.maxY.isFinite
            }
            // An existing but invalid label must never supply a direction.
            guard (!titleExists || measurable(titleFrame)),
                  (!timeExists || measurable(timeFrame)) else { return (false, .zero, .zero, .zero) }
            let completeRecord = titleExists && timeExists
            let targetFrame: CGRect
            if completeRecord {
                targetFrame = titleFrame.union(timeFrame)
            } else {
                // The actual dated section is already in the native hierarchy
                // even when List has not materialized its event row yet.
                guard dayHeader.exists else { return (false, .zero, .zero, .zero) }
                let headerFrame = dayHeader.frame
                guard measurable(headerFrame) else { return (false, .zero, .zero, .zero) }
                targetFrame = headerFrame
            }
            let applicationFrame = app.frame
            let listFrame = list.frame
            var bounds = listFrame.intersection(applicationFrame)
            let header = app.staticTexts["calendar_range"]
            if header.exists { bounds.origin.y = max(bounds.minY, header.frame.maxY) }
            let navigation = app.navigationBars.firstMatch
            if navigation.exists { bounds.origin.y = max(bounds.minY, navigation.frame.maxY) }
            let tabBar = app.tabBars.firstMatch
            var bottom = min(listFrame.maxY, applicationFrame.maxY)
            if tabBar.exists { bottom = min(bottom, tabBar.frame.minY) }
            bounds.size.height = max(0, bottom - bounds.minY)
            bounds = bounds.insetBy(dx: 4, dy: 8)
            return (completeRecord && !bounds.isEmpty && !titleFrame.isEmpty && !timeFrame.isEmpty
                && bounds.contains(titleFrame) && bounds.contains(timeFrame),
                listFrame, bounds, targetFrame)
        }
        for _ in 0..<8 {
            let state = inspection()
            if state.readable { break }
            guard Date() < deadline, list.exists else { break }
            // Recenter by the measured gap, using the same public bounded
            // drag as the canonical incremental journey. One drag uses one
            // of the original eight actions; both endpoints stay unobscured.
            guard !state.listFrame.isEmpty, !state.viewport.isEmpty, !state.content.isEmpty,
                  state.listFrame.minX.isFinite, state.listFrame.minY.isFinite,
                  state.listFrame.width.isFinite, state.listFrame.height.isFinite,
                  state.viewport.width.isFinite, state.viewport.height.isFinite,
                  state.viewport.midX.isFinite, state.viewport.midY.isFinite,
                  state.content.midY.isFinite else { break }
            let limit = min(120, max(0, state.viewport.height / 2 - 8))
            let distance = min(limit, max(-limit, state.viewport.midY - state.content.midY))
            guard distance.isFinite, distance != 0 else { break }
            let offset = CGVector(
                dx: (state.viewport.midX - state.listFrame.minX) / state.listFrame.width,
                dy: (state.viewport.midY - state.listFrame.minY) / state.listFrame.height)
            let start = list.coordinate(withNormalizedOffset: offset)
            let end = start.withOffset(CGVector(dx: 0, dy: distance))
            guard Date() < deadline else { break }
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let final = inspection().readable
        XCTAssertTrue(final, "Fixed record title and exact timestamp must be fully visible outside the sticky header and tab bar")
        guard final else {
            retainHierarchy("personal-fixed-record-not-readable")
            throw CaptureFailure.unavailable
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

    /// Captured UIKit AX exposes the popup as a DatePicker with native month
    /// controls and a CollectionView of fully labelled date buttons. Its drawn
    /// weekday strip is an unlabelled Other, not seven StaticText elements.
    @MainActor
    private func nativePickerGrid() -> (labels: [String], firstWeekday: Int)? {
        // Public XCUIElementSnapshotProviding captures the same attributes
        // together; enumerating date cells must not trigger a live Find each.
        guard let snapshot = try? app.snapshot() else { return nil }
        func descendants(_ root: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
            var result: [any XCUIElementSnapshot] = []
            var pending = Array(root.children.reversed())
            while let element = pending.popLast() {
                result.append(element)
                pending.append(contentsOf: element.children.reversed())
            }
            return result
        }
        guard let popup = descendants(snapshot).first(where: { element in
            element.elementType == .datePicker
                && descendants(element).contains { $0.elementType == .collectionView }
        }) else { return nil }
        let elements = descendants(popup)
        guard elements.contains(where: { $0.elementType == .button && $0.identifier == "DatePicker.Show" }),
              elements.contains(where: { $0.elementType == .button && $0.identifier == "DatePicker.PreviousMonth" }),
              elements.contains(where: { $0.elementType == .button && $0.identifier == "DatePicker.NextMonth" }),
              let collection = elements.first(where: { $0.elementType == .collectionView }) else { return nil }
        let applicationFrame = snapshot.frame
        let bounds = collection.frame
        guard !bounds.isEmpty && bounds.intersects(applicationFrame) else { return nil }
        let headerBandExists = elements.filter { $0.elementType == .other }.contains { element in
            let frame = element.frame
            return frame.width >= bounds.width * 0.9 && frame.height > 0 && frame.height < 40
                && frame.minY >= bounds.minY - 40 && frame.maxY <= bounds.minY + 2
                && frame.intersects(applicationFrame)
        }
        guard headerBandExists else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        guard let anchor = civilFormatter().date(from: config["anchorCivilDay"] as? String ?? "") else { return nil }
        let year = calendar.component(.year, from: anchor)
        let month = calendar.component(.month, from: anchor)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: chinese ? "zh_CN" : "en_US")
        let weekdays: [String] = formatter.weekdaySymbols
        let monthName = chinese ? "\(month)月" : formatter.monthSymbols[month - 1]
        let shownMonth = elements.first { $0.elementType == .button && $0.identifier == "DatePicker.Show" }?.value as? String ?? ""
        guard shownMonth.contains(String(year)) && shownMonth.contains(monthName) else { return nil }

        let cells = descendants(collection).filter { $0.elementType == .button }.compactMap { element -> (date: Date, frame: CGRect)? in
            let frame = element.frame
            guard !frame.isEmpty && frame.intersects(bounds) && frame.intersects(applicationFrame) else { return nil }
            let label = element.label
            let numbers = label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            let day: Int
            if chinese {
                guard numbers.count == 2 && numbers[0] == month else { return nil }
                day = numbers[1]
            } else {
                guard numbers.count == 1 && label.contains(monthName) else { return nil }
                day = numbers[0]
            }
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.month, from: date) == month,
                  calendar.component(.day, from: date) == day,
                  label.contains(weekdays[calendar.component(.weekday, from: date) - 1]) else { return nil }
            return (date, frame)
        }
        guard cells.count >= 28 else { return nil }
        var columns: [CGFloat] = []
        for x in cells.map({ $0.frame.midX }).sorted() {
            if columns.last.map({ abs($0 - x) > 2 }) ?? true { columns.append(x) }
        }
        guard columns.count == 7 else { return nil }
        for cell in cells {
            let row = cells.filter { abs($0.frame.midY - cell.frame.midY) < 2 }
                .sorted { $0.frame.midX < $1.frame.midX }
            guard row.count == 7 else { continue }
            let firstWeekday = calendar.component(.weekday, from: row[0].date)
            let completeWeek = row.enumerated().allSatisfy { index, item in
                calendar.dateComponents([.day], from: row[0].date, to: item.date).day == index
                    && calendar.component(.weekday, from: item.date) == (firstWeekday - 1 + index) % 7 + 1
                    && abs(item.frame.midX - columns[index]) <= 2
            }
            guard completeWeek else { continue }
            let allCellsAgree = cells.allSatisfy { item in
                guard let column = columns.firstIndex(where: { abs($0 - item.frame.midX) <= 2 }) else { return false }
                return calendar.component(.weekday, from: item.date) == (firstWeekday - 1 + column) % 7 + 1
            }
            guard allCellsAgree else { return nil }
            // Requiring firstWeekday == 1 in the candidate caller proves that
            // every semantically Sunday date is in the actual leftmost column.
            return (row.map { weekdays[calendar.component(.weekday, from: $0.date) - 1] }, firstWeekday)
        }
        return nil
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

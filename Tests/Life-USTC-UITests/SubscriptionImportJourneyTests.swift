import XCTest

final class SubscriptionImportJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, catalogHistory: true)
        fixture.includeHistoricalSubscription()
        app = XCUIApplication()
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
        }
        let requests = XCTAttachment(string: fixture.requests.map {
            "\($0.method) \($0.path) \($0.query) \(String(data: $0.body, encoding: .utf8) ?? "")"
        }.joined(separator: "\n"))
        requests.name = "subscription-import-requests"
        requests.lifetime = .keepAlways
        add(requests)
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testImportEnglishPreviewsAndAppendsOnlySelectedSections() async throws {
        try await successfulImport(language: "en", locale: "en_US")
    }

    @MainActor
    func testImportChinesePreviewsAndAppendsOnlySelectedSections() async throws {
        try await successfulImport(language: "zh-Hans", locale: "zh_CN")
    }

    @MainActor
    func testFailedAppendPreservesSelectionAndAllowsExplicitRetry() async throws {
        launch(language: "en", locale: "en_US")
        try await open("home_subscriptions")
        try await open("subscriptions_import_codes")
        try await chooseSemester("Spring 2026")
        try await setCodes("PHYS101")
        try await open("subscription_import_preview")
        let selected = app.switches["subscription_import_section_10"]
        reveal(selected)
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        try await deselectSection(11)
        fixture.includeConcurrentImportSubscription()
        fixture.failNextRequest(method: "POST", path: "/api/workspace/subscriptions/batch")
        try await open("subscription_import_confirm")
        let error = app.staticTexts["subscription_import_error"]
        reveal(error)
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        reveal(selected)
        XCTAssertEqual(selected.value as? String, "1")
        XCTAssertEqual(batchRequests.count, 1)
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular", 47: "auditor"])
        capture("FailedAppend", language: "en")
        try await open("subscription_import_confirm")
        assertSuccessfulAppend()
        XCTAssertEqual(batchRequests.count, 2)
        XCTAssertTrue(batchRequests.allSatisfy { $0.jsonBody["sectionIds"] as? [Int] == [10] })
    }

    @MainActor
    func testQueryRetryAndChangedSemesterOrCodesRequireFreshPreview() async throws {
        launch(language: "en", locale: "en_US")
        try await open("home_subscriptions")
        try await open("subscriptions_import_codes")
        XCTAssertFalse(app.buttons["subscription_import_preview"].isEnabled)
        try await chooseSemester("Spring 2026")
        try await setCodes("PHYS101")
        fixture.failNextRequest(method: "POST", path: "/api/workspace/subscriptions/query")
        try await open("subscription_import_preview")
        let error = app.staticTexts["subscription_import_error"]
        reveal(error)
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        let input = app.textViews["subscription_import_input"]
        reveal(input)
        XCTAssertEqual(input.value as? String, "PHYS101")
        try await open("subscription_import_preview")
        let match = app.switches["subscription_import_section_10"]
        reveal(match)
        XCTAssertTrue(match.waitForExistence(timeout: 10))
        try await chooseSemester("2026 Fall")
        try await open("subscription_import_preview")
        let empty = app.staticTexts["subscription_import_empty"]
        reveal(empty)
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        try await setCodes("UNKNOWN.01")
        try await open("subscription_import_preview")
        let unmatched = app.otherElements["subscription_import_unmatched_UNKNOWN.01"]
        let unmatchedText = app.staticTexts["UNKNOWN.01"]
        reveal(unmatchedText)
        XCTAssertTrue(unmatched.exists || unmatchedText.waitForExistence(timeout: 10))
        XCTAssertTrue(batchRequests.isEmpty)
        let requests = queryRequests
        XCTAssertEqual(requests.count, 4)
        XCTAssertEqual(requests.map { $0.jsonBody["semesterId"] as? Int }, [2, 2, 1, 1])
        XCTAssertEqual(requests.last?.jsonBody["codes"] as? [String], ["UNKNOWN.01"])
        capture("Unmatched", language: "en")
    }

    @MainActor
    private func successfulImport(language: String, locale: String) async throws {
        launch(language: language, locale: locale)
        try await open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscription_42"].waitForExistence(timeout: 10))
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular"])
        capture("Subscriptions", language: language)
        try await open("subscriptions_import_codes")
        try await chooseSemester(language == "en" ? "Spring 2026" : "2026年春季学期")
        let codes = "PHYS101 PHYS101.01 PHYS101.09"
        try await setCodes(codes)
        capture("Entry", language: language)
        try await open("subscription_import_preview")
        let existing = app.switches["subscription_import_section_8"]
        reveal(existing)
        XCTAssertTrue(existing.waitForExistence(timeout: 10))
        XCTAssertFalse(existing.isEnabled)
        XCTAssertEqual(existing.value as? String, "0")
        try await deselectSection(11)
        let suggestions = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@",
            language == "en" ? "Suggested codes:" : "建议代码：")).firstMatch
        reveal(suggestions)
        XCTAssertTrue(suggestions.waitForExistence(timeout: 10))
        XCTAssertTrue(suggestions.label.contains("PHYS101.01"))
        reveal(existing)
        capture("Preview", language: language)
        XCTAssertEqual(queryRequests.count, 1)
        XCTAssertEqual(queryRequests.first?.jsonBody["semesterId"] as? Int, 2)
        XCTAssertEqual(queryRequests.first?.jsonBody["codes"] as? [String], codes.components(separatedBy: " "))
        XCTAssertEqual(queryRequests.first?.query["locale"], language == "en" ? "en-us" : "zh-cn")
        XCTAssertTrue(batchRequests.isEmpty)
        fixture.includeConcurrentImportSubscription()
        try await open("subscription_import_confirm")
        assertSuccessfulAppend()
        XCTAssertEqual(batchRequests.count, 1)
        XCTAssertEqual(batchRequests.first?.jsonBody["action"] as? String, "add")
        XCTAssertEqual(batchRequests.first?.jsonBody["sectionIds"] as? [Int], [10])
        XCTAssertEqual(Set(batchRequests.first?.jsonBody.keys.map { $0 } ?? []), ["action", "sectionIds"])
        XCTAssertEqual(batchRequests.first?.query["locale"], language == "en" ? "en-us" : "zh-cn")
        capture("Result", language: language)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let added = app.buttons["subscription_45"]
        reveal(added)
        XCTAssertTrue(added.waitForExistence(timeout: 10), "The subscription list must refresh after import")
        XCTAssertTrue(fixture.requests.filter { $0.path.hasPrefix("/api/workspace/") }.allSatisfy {
            $0.headers["authorization"] == "Bearer \(ServerJourneyHTTPFixture.token)"
        })
    }

    @MainActor
    private func assertSuccessfulAppend() {
        let added = app.staticTexts["subscription_import_added"]
        reveal(added)
        XCTAssertTrue(added.waitForExistence(timeout: 10))
        XCTAssertTrue(added.label.contains("1"))
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular", 45: "regular", 47: "auditor"])
        XCTAssertNil(fixture.subscriptionKinds[46], "The deselected match must not be subscribed")
    }

    private var queryRequests: [ServerJourneyHTTPFixture.Request] {
        fixture.requests.filter { $0.method == "POST" && $0.path == "/api/workspace/subscriptions/query" }
    }

    private var batchRequests: [ServerJourneyHTTPFixture.Request] {
        fixture.requests.filter { $0.method == "POST" && $0.path == "/api/workspace/subscriptions/batch" }
    }

    @MainActor
    private func launch(language: String, locale: String) {
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "UI_TEST_SKIP_ONBOARDING"]
        app.launch()
    }

    @MainActor
    private func chooseSemester(_ title: String) async throws {
        try await open("subscription_import_semester")
        try await open(title)
    }

    @MainActor
    private func setCodes(_ text: String) async throws {
        let field = app.textViews["subscription_import_input"]
        reveal(field)
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("Missing course-code input")
            throw InteractionFailure.unavailableControl
        }
        let previous = field.value as? String ?? ""
        field.tap()
        if !previous.isEmpty {
            field.press(forDuration: 1)
            let selectAll = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
            guard selectAll.waitForExistence(timeout: 5) else {
                XCTFail("Missing Select All action for existing course codes")
                throw InteractionFailure.unavailableControl
            }
            selectAll.tap()
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            try await waitFor(field, predicate: "value == ''")
        }
        field.typeText(text)
        let expected = NSPredicate(format: "value == %@", text)
        let updated = XCTNSPredicateExpectation(predicate: expected, object: field)
        let result = await XCTWaiter.fulfillment(of: [updated], timeout: 10)
        guard result == .completed, field.value as? String == text else {
            XCTFail("Course codes were not replaced with the requested text")
            throw InteractionFailure.unavailableControl
        }
    }

    @MainActor
    private func deselectSection(_ id: Int, file: StaticString = #filePath, line: UInt = #line) async throws {
        let field = app.switches["subscription_import_section_\(id)"]
        reveal(field)
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("Missing switch: \(id)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
        guard field.value as? String == "1" else {
            XCTFail("Expected section \(id) to be selected", file: file, line: line)
            throw InteractionFailure.unexpectedSelection
        }
        let control = field.switches.firstMatch
        guard control.waitForExistence(timeout: 10) else {
            XCTFail("Missing native switch for section \(id)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
        reveal(control)
        try await waitFor(control, predicate: "enabled == true AND hittable == true", file: file, line: line)
        // The labelled row activates its text, while the native switch's center
        // can miss the selected thumb. Use the thumb inside the switch bounds.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        try await waitFor(field, predicate: "value == '0'", file: file, line: line)
    }

    @MainActor
    private func capture(_ page: String, language: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-subscription-import-\(language)-\(page)-"
            + (UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")
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

    private enum InteractionFailure: Error {
        case unavailableControl
        case unexpectedSelection
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, predicate: String,
                         file: StaticString = #filePath, line: UInt = #line) async throws {
        let condition = NSPredicate(format: predicate)
        // A native accessibility query can itself take longer than the polling
        // deadline. Accept an already-satisfied condition before starting it.
        if condition.evaluate(with: element) { return }
        let expectation = XCTNSPredicateExpectation(predicate: condition, object: element)
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 10)
        guard result == .completed else {
            XCTFail("Control did not satisfy \(predicate): \(element)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
    }

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let button = app.buttons.matching(identifier: id).firstMatch
        _ = button.waitForExistence(timeout: 2)
        reveal(button)
        guard button.waitForExistence(timeout: 10) else {
            XCTFail("Missing control: \(id)", file: file, line: line)
            throw InteractionFailure.unavailableControl
        }
        try await waitFor(button, predicate: "enabled == true AND hittable == true", file: file, line: line)
        button.tap()
        if id == "subscription_import_preview" {
            try await waitFor(app.keyboards.firstMatch, predicate: "exists == false", file: file, line: line)
        }
    }
}

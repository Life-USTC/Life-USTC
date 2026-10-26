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
    func testImportEnglishPreviewsAndAppendsOnlySelectedSections() async {
        await successfulImport(language: "en", locale: "en_US")
    }

    @MainActor
    func testImportChinesePreviewsAndAppendsOnlySelectedSections() async {
        await successfulImport(language: "zh-Hans", locale: "zh_CN")
    }

    @MainActor
    func testFailedAppendPreservesSelectionAndAllowsExplicitRetry() async {
        launch(language: "en", locale: "en_US")
        await open("home_subscriptions")
        await open("subscriptions_import_codes")
        await chooseSemester("Spring 2026")
        setCodes("PHYS101")
        await open("subscription_import_preview")
        let selected = app.switches["subscription_import_section_10"]
        reveal(selected)
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        deselectSection(11)
        fixture.includeConcurrentImportSubscription()
        fixture.failNextRequest(method: "POST", path: "/api/workspace/subscriptions/batch")
        await open("subscription_import_confirm")
        let error = app.staticTexts["subscription_import_error"]
        reveal(error)
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        reveal(selected)
        XCTAssertEqual(selected.value as? String, "1")
        XCTAssertEqual(batchRequests.count, 1)
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular", 47: "auditor"])
        capture("FailedAppend", language: "en")
        await open("subscription_import_confirm")
        assertSuccessfulAppend()
        XCTAssertEqual(batchRequests.count, 2)
        XCTAssertTrue(batchRequests.allSatisfy { $0.jsonBody["sectionIds"] as? [Int] == [10] })
    }

    @MainActor
    func testQueryRetryAndChangedSemesterOrCodesRequireFreshPreview() async {
        launch(language: "en", locale: "en_US")
        await open("home_subscriptions")
        await open("subscriptions_import_codes")
        XCTAssertFalse(app.buttons["subscription_import_preview"].isEnabled)
        await chooseSemester("Spring 2026")
        setCodes("PHYS101")
        fixture.failNextRequest(method: "POST", path: "/api/workspace/subscriptions/query")
        await open("subscription_import_preview")
        let error = app.staticTexts["subscription_import_error"]
        reveal(error)
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        let input = app.textViews["subscription_import_input"]
        reveal(input)
        XCTAssertEqual(input.value as? String, "PHYS101")
        await open("subscription_import_preview")
        let match = app.switches["subscription_import_section_10"]
        reveal(match)
        XCTAssertTrue(match.waitForExistence(timeout: 10))
        await chooseSemester("2026 Fall")
        await open("subscription_import_preview")
        let empty = app.staticTexts["subscription_import_empty"]
        reveal(empty)
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        setCodes("UNKNOWN.01")
        await open("subscription_import_preview")
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
    private func successfulImport(language: String, locale: String) async {
        launch(language: language, locale: locale)
        await open("home_subscriptions")
        XCTAssertTrue(app.buttons["subscription_42"].waitForExistence(timeout: 10))
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular"])
        capture("Subscriptions", language: language)
        await open("subscriptions_import_codes")
        await chooseSemester(language == "en" ? "Spring 2026" : "2026年春季学期")
        let codes = "PHYS101 PHYS101.01 PHYS101.09"
        setCodes(codes)
        capture("Entry", language: language)
        await open("subscription_import_preview")
        let existing = app.switches["subscription_import_section_8"]
        reveal(existing)
        XCTAssertTrue(existing.waitForExistence(timeout: 10))
        XCTAssertFalse(existing.isEnabled)
        XCTAssertEqual(existing.value as? String, "0")
        deselectSection(11)
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
        await open("subscription_import_confirm")
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
    private func chooseSemester(_ title: String) async {
        await open("subscription_import_semester")
        await open(title)
    }

    @MainActor
    private func setCodes(_ text: String) {
        let field = app.textViews["subscription_import_input"]
        reveal(field)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let previous = field.value as? String ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + text)
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 10), .completed)
        XCTAssertEqual(field.value as? String, text)
    }

    @MainActor
    private func deselectSection(_ id: Int) {
        let field = app.switches["subscription_import_section_\(id)"]
        reveal(field)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "1")
        let control = field.switches.firstMatch
        (control.exists ? control : field).tap()
        XCTAssertEqual(field.value as? String, "0")
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

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) async {
        let button = app.buttons.matching(identifier: id).firstMatch
        _ = button.waitForExistence(timeout: 2)
        reveal(button)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(id)", file: file, line: line)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        let result = await XCTWaiter.fulfillment(of: [ready], timeout: 10)
        XCTAssertEqual(result, .completed, file: file, line: line)
        button.tap()
    }
}

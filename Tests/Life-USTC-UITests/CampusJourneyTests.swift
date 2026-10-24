import XCTest

final class CampusJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, campus: true)
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
    func testCatalogSearchOpensNativeSectionCourseAndTeacherDetails() throws {
        launchDiscover()
        capture("Discover")
        open("discover_search")
        let field = app.searchFields.firstMatch
        if !field.exists { app.swipeDown() }
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Calculus")
        waitForRequest("GET", "/api/search", query: ["q": "Calculus", "scope": "catalog"])
        openSearchResult("campus_search_section:42")
        waitForRequest("GET", "/api/catalog/sections/42")
        XCTAssertTrue(app.buttons["section_subscribe"].waitForExistence(timeout: 10))
        back()
        openSearchResult("campus_search_course:1001")
        waitForRequest("GET", "/api/catalog/courses/1001")
        assertText("Calculus")
        back()
        openSearchResult("campus_search_teacher:3")
        waitForRequest("GET", "/api/catalog/teachers/3")
        back()
        capture("Search")
        XCTAssertFalse(fixture.requests.contains { $0.path == "/api/catalog/sections/7" })
    }

    @MainActor
    func testLinkPinFailureKeepsConfirmedStateAndRetryPersistsExplicitUnpin() throws {
        fixture.failNextRequest(method: "POST", path: "/api/workspace/link-pins/batch")
        launchDiscover()
        open("discover_links")
        waitForRequest("GET", "/api/workspace/link-pins")
        let pin = app.buttons.matching(identifier: "campus_pin_academic").firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, "Unpin Link")
        capture("Links")
        open("campus_pin_academic")
        assertText("Workspace fixture unavailable")
        XCTAssertEqual(pin.label, "Unpin Link")
        open("Retry")
        waitUntil { self.requestCount("POST", "/api/workspace/link-pins/batch") == 2 }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Pin Link"), object: pin)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let request = try XCTUnwrap(fixture.requests.last { $0.method == "POST" && $0.path == "/api/workspace/link-pins/batch" })
        XCTAssertEqual(request.jsonBody["items"] as? [[String: String]], [["slug": "academic", "action": "unpin"]])
        back()
        open("discover_links")
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, "Pin Link")
    }

    @MainActor
    func testPinReadFailureLeavesSearchAvailableAndRequiresRetryBeforeWriting() throws {
        fixture.failNextRequest(method: "GET", path: "/api/workspace/link-pins")
        launchDiscover()
        open("discover_links")
        assertText("Workspace fixture unavailable")
        XCTAssertFalse(app.buttons["campus_pin_academic"].exists)
        let field = app.searchFields.firstMatch
        if !field.exists { app.swipeDown() }
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("jiaowu")
        assertText("Academic Portal")
        XCTAssertFalse(app.staticTexts["University Library"].exists)
        XCTAssertEqual(requestCount("POST", "/api/workspace/link-pins/batch"), 0)
        open("Retry")
        XCTAssertTrue(app.buttons.matching(identifier: "campus_pin_academic").firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testBusUsesExplicitRouteAndSavesPreferenceOnlyAfterUserRequest() throws {
        launchDiscover()
        open("discover_bus")
        waitForRequest("GET", "/api/catalog/bus/next", query: ["originCampusId": "1", "destinationCampusId": "2"])
        assertText("23:00")
        assertText("23:30")
        capture("Bus")
        XCTAssertEqual(requestCount("POST", "/api/workspace/bus-preferences"), 0)
        let toggle = app.switches["Show Departed Trips"]
        for _ in 0..<6 {
            if toggle.exists && toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let control = toggle.switches.firstMatch
        (control.exists ? control : toggle).tap()
        XCTAssertEqual(requestCount("POST", "/api/workspace/bus-preferences"), 0)
        fixture.failNextRequest(method: "POST", path: "/api/workspace/bus-preferences")
        open("bus_save_preferences")
        assertText("Workspace fixture unavailable")
        open("Retry")
        waitUntil { self.requestCount("POST", "/api/workspace/bus-preferences") == 2 }
        let saved = try XCTUnwrap(fixture.requests.last { $0.method == "POST" && $0.path == "/api/workspace/bus-preferences" })
        XCTAssertEqual(saved.jsonBody["preferredOriginCampusId"] as? Int, 1)
        XCTAssertEqual(saved.jsonBody["preferredDestinationCampusId"] as? Int, 2)
        XCTAssertEqual(saved.jsonBody["showDepartedTrips"] as? Bool, true)
        let button = app.buttons["bus_save_preferences"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 10), .completed)
        app.terminate()
        launchDiscover()
        open("discover_bus")
        waitUntil { self.requestCount("GET", "/api/workspace/bus-preferences") >= 2 }
        for _ in 0..<6 {
            if toggle.exists && toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor
    func testWeatherSwitchesCanonicalLocationsAndShowsForecastProvenance() throws {
        launchDiscover()
        open("discover_weather")
        waitForRequest("GET", "/api/catalog/weather", query: ["locationKey": "ustc-main"])
        assertText("Partly cloudy")
        assertText("Observed at")
        capture("Weather")
        let locations = app.segmentedControls["weather_location"]
        XCTAssertTrue(locations.waitForExistence(timeout: 10))
        locations.buttons["Gaoxin Campus"].tap()
        waitForRequest("GET", "/api/catalog/weather", query: ["locationKey": "ustc-gaoxin"])
        assertText("Hourly Forecast")
        assertText("Daily Forecast")
        assertText("No active weather alerts.")
        assertText("Weather providers: AMap, Open-Meteo")
    }

    @MainActor
    func testRoomLookupNormalizesCodeAndDisplaysUnavailableResultWithoutGuessingMap() throws {
        launchDiscover()
        open("discover_rooms")
        let field = app.textFields["room_code"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("gt-999")
        open("room_lookup")
        waitForRequest("GET", "/api/catalog/rooms/GT-999/map")
        assertText("Map unavailable")
        assertText("No map is available for this room code.")
        XCTAssertFalse(app.buttons["Expand Map"].exists)
        capture("RoomMap")
    }

    @MainActor
    func testAnonymousBusRoutePersistsAfterLeavingThePlannerWithoutPrivateRequests() throws {
        fixture.enableBusParityFixture()
        app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = nil
        launchDiscover()
        open("discover_bus")
        open("bus_origin")
        open("East Campus")
        open("bus_destination")
        open("Gaoxin Campus")
        open("bus_reverse")
        waitForRequest("GET", "/api/catalog/bus/next", query: ["originCampusId": "2", "destinationCampusId": "1"])
        back()
        open("discover_bus")
        waitUntil {
            self.fixture.requests.filter {
                $0.path == "/api/catalog/bus/next" && $0.query["originCampusId"] == "2" && $0.query["destinationCampusId"] == "1"
            }.count >= 2
        }
        XCTAssertFalse(fixture.requests.contains { $0.path.hasPrefix("/api/workspace/") })
        XCTAssertFalse(app.buttons["bus_save_preferences"].exists)
        captureM6("BusRecentRoute")
    }

    @MainActor
    func testBusMapShowsEstimatedVehicleAndExplainsTimetableProvenance() throws {
        fixture.enableBusParityFixture()
        launchDiscover()
        open("discover_bus")
        open("Shuttle Map")
        assertText("Bus positions are timetable estimates, not GPS locations.")
        let estimate = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Estimated bus location")).firstMatch
        XCTAssertTrue(estimate.waitForExistence(timeout: 10))
        captureM6("BusMap")
    }

    @MainActor
    private func captureM6(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m6-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func launchDiscover() {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        } else {
            let tab = app.buttons["Tab.Discover"]
            if !tab.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 10))
                toggle.tap()
            }
            XCTAssertTrue(tab.isHittable)
            tab.tap()
        }
        XCTAssertTrue(app.buttons["discover_catalog"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m4-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func openSearchResult(_ id: String) {
        let result = app.buttons.containing(.staticText, identifier: id).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        for _ in 0..<6 {
            if result.isHittable { break }
            app.swipeUp()
        }
        result.tap()
    }

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
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
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(id)", file: file, line: line)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, "Unavailable control: \(id)", file: file, line: line)
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

    private func waitForRequest(_ method: String, _ path: String, query: [String: String] = [:]) {
        waitUntil {
            self.fixture.requests.contains { request in
                request.method == method && request.path == path && query.allSatisfy { request.query[$0.key] == $0.value }
            }
        }
    }

    private func waitUntil(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
}

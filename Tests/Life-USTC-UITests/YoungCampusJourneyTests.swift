import XCTest

final class YoungCampusJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, youngCampus: true)
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
    func testActivityFiltersApplyCancelClearAndPreserveUnknownDateContext() throws {
        fixture.enablePublicDiscoveryFixture()
        app.launch()
        openYoung()
        open("Activities")
        assertText("Campus workshop · 智 · 校级")
        assertText("Campus workshop · 未来模块 · 国际级")
        let search = app.searchFields.firstMatch
        reveal(search)
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Science\n")
        waitForRequest("GET", "/api/catalog/young-events", query: ["search": "Science"])

        open("young.filters")
        let category = app.textFields["young.filters.category"]
        XCTAssertTrue(category.waitForExistence(timeout: 10))
        category.tap()
        category.typeText("Campus workshop\n")
        chooseFilter("module", value: "智")
        chooseFilter("activityLevel", value: "校级")
        chooseFilter("timeBasis", value: "Registration window")
        toggle("young.filters.dateRange")
        chooseFilter("active", value: "In source signup list")
        chooseFilter("organizer", value: "Student Science Association")
        capture("YoungFilters")
        open("young.filters.apply")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let expected = ["search": "Science", "category": "Campus workshop", "module": "智",
                        "activityLevel": "校级", "timeBasis": "registration", "active": "true",
                        "organizerId": PublicDiscoveryHTTPState.scienceOrganizer, "dateFrom": today, "dateTo": today]
        waitForRequest("GET", "/api/catalog/young-events", query: expected)
        assertText("1 activities have unknown dates")
        XCTAssertFalse(app.staticTexts["Science Alumni Forum"].exists)
        open("young.unknownDates")
        var unknown = expected
        unknown["dateUnknown"] = "true"
        unknown.removeValue(forKey: "dateFrom")
        unknown.removeValue(forKey: "dateTo")
        waitForRequest("GET", "/api/catalog/young-events", query: unknown)
        assertText("Science Undated Workshop")
        XCTAssertFalse(app.staticTexts["Music Undated Circle"].exists)
        XCTAssertFalse(app.staticTexts["Science Unlisted Seminar"].exists)
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/api/catalog/young-events" })
        XCTAssertNil(request.query["dateFrom"])
        XCTAssertNil(request.query["dateTo"])
        capture("YoungFilteredUnknownDates")

        open("young.filters")
        assertText("Date ranges do not apply to activities with unknown dates.")
        XCTAssertFalse(app.switches["young.filters.dateRange"].exists)
        chooseFilter("active", value: "Not in source signup list")
        open("young.filters.cancel")
        assertText("Science Undated Workshop")
        XCTAssertFalse(fixture.requests.contains { $0.path == "/api/catalog/young-events" && $0.query["active"] == "false" })
        open("young.filters")
        chooseFilter("active", value: "Not in source signup list")
        open("young.filters.apply")
        unknown["active"] = "false"
        waitForRequest("GET", "/api/catalog/young-events", query: unknown)
        assertText("Science Unlisted Seminar")
        XCTAssertFalse(app.staticTexts["Science Undated Workshop"].exists)

        open("young.filters")
        open("young.filters.clear")
        open("young.filters.apply")
        waitUntil {
            self.fixture.requests.contains { $0.path == "/api/catalog/young-events" && $0.query["dateUnknown"] == "true"
                && $0.query["search"] == "Science" && $0.query["timeBasis"] == "activity" && $0.query["active"] == nil }
        }
        assertText("Science Undated Workshop")
        assertText("Science Unlisted Seminar")
        XCTAssertFalse(app.staticTexts["Music Undated Circle"].exists)
        back()
        open("young.filters")
        XCTAssertEqual(switchControl("young.filters.dateRange").value as? String, "1")
        open("young.filters.cancel")
    }

    @MainActor
    func testActivityFilterOrganizerRetryAndEmptyResultRecovery() throws {
        fixture.enablePublicDiscoveryFixture()
        app.launch()
        openYoung()
        open("Activities")
        fixture.failNextRequest(method: "GET", path: "/api/catalog/young-organizers")
        open("young.filters")
        assertText("Workspace fixture unavailable")
        open("young.filters.organizers.retry")
        chooseFilter("organizer", value: "Student Arts Association")
        chooseFilter("module", value: "智")
        open("young.filters.apply")
        waitForRequest("GET", "/api/catalog/young-events", query: ["organizerId": PublicDiscoveryHTTPState.artsOrganizer, "module": "智"])
        assertText("There are no activities matching this filter.")
        open("young.filters")
        let organizer = app.buttons["young.filters.organizer"]
        XCTAssertTrue(organizer.label.contains("Student Arts Association")
                      || (organizer.value as? String)?.contains("Student Arts Association") == true)
        open("young.filters.clear")
        open("young.filters.apply")
        assertText("Science Communication Workshop")
        assertText("Arts Practice Workshop")
    }

    @MainActor
    func testActivityFactsPrioritizeOfficialSignupAndLabelSourceListAccurately() throws {
        app.launch()
        openYoung()
        open("Activities")
        openText("Science Communication Workshop")
        assertText("Activity time")
        assertText("Registration starts soon")
        captureM6("YoungDetail")
        let signup = app.descendants(matching: .any).matching(identifier: "young.signup").firstMatch
        reveal(signup)
        XCTAssertTrue(signup.exists)
        let subscription = switchControl("young.subscription.enabled")
        XCTAssertLessThan(signup.frame.minY, subscription.frame.minY)
        for hidden in ["Registered", "Graduate students only", "800-414-186", "External sponsor fixture",
                       "Additional registration information required", "Accepted attachment formats"] {
            XCTAssertFalse(app.staticTexts[hidden].exists, "Unexpected default participation field: \(hidden)")
        }
        captureM6("YoungDetailParticipation")
        back()
        back()
        open("Followed Organizers")
        openText("Student Science Association")
        assertText("1 in source signup list")
        XCTAssertFalse(app.staticTexts["1 open"].exists)
        captureM6("YoungOrganizer")
    }

    @MainActor
    func testPublicationRendersCanonicalImageOrderTableAndUsefulAttribution() throws {
        app.launch()
        selectDiscover()
        open("discover_publications")
        open("publication.row.\(YoungCampusHTTPState.publicationID)")
        let before = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Before the campus demonstration.")).firstMatch
        XCTAssertTrue(before.waitForExistence(timeout: 10))
        assertText("Before the campus demonstration.")
        captureM6("PublicationDetail")
        assertText("Students share their laboratory work.")
        waitForRequest("GET", "/api/publications/images/" + String(repeating: "b", count: 64))
        let caption = app.webViews.staticTexts["Students share their laboratory work."]
        let after = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "After the campus demonstration.")).firstMatch
        XCTAssertTrue(before.exists && caption.exists && after.exists)
        XCTAssertLessThan(before.frame.minY, caption.frame.minY)
        XCTAssertLessThan(caption.frame.minY, after.frame.minY)
        captureM6("PublicationImage")
        assertText("East 101")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "| --- | --- |")).firstMatch.exists)
        assertText("Campus Newsroom")
        XCTAssertFalse(app.staticTexts["栏目"].exists)
        XCTAssertFalse(app.staticTexts["https://example.org/editor"].exists)
        XCTAssertFalse(app.staticTexts["—"].exists)
        captureM6("PublicationAttribution")
    }

    @MainActor
    private func captureM6(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m6-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUpstreamStatusAndReminderFailurePreserveSettingsUntilRetry() throws {
        let path = "/api/workspace/young-event-subscriptions/\(YoungCampusHTTPState.eventID)"
        fixture.failNextRequest(method: "PUT", path: path)
        app.launch()
        openYoung()
        capture("Young")
        open("Activities")
        waitForRequest("GET", "/api/catalog/young-events")
        assertText("Registration starts soon")
        capture("YoungActivities")
        openText("Science Communication Workshop")
        _ = switchControl("young.subscription.deadline")
        waitForRequest("GET", path)
        toggle("young.subscription.deadline")
        assertText("Workspace fixture unavailable")
        XCTAssertEqual(switchControl("young.subscription.deadline").value as? String, "0")
        open("young.subscription.retry")
        waitUntil { self.fixture.requests.filter { $0.method == "PUT" && $0.path == path }.count == 2 }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"),
                                                object: switchControl("young.subscription.deadline"))
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed)
        let writes = fixture.requests.filter { $0.method == "PUT" && $0.path == path }
        XCTAssertEqual(writes[0].jsonBody as NSDictionary, writes[1].jsonBody as NSDictionary)
        XCTAssertEqual(writes[1].jsonBody["subscribed"] as? Bool, true)
        XCTAssertEqual(writes[1].jsonBody["remindSignup"] as? Bool, true)
        XCTAssertEqual(writes[1].jsonBody["remindDeadline"] as? Bool, true)
        XCTAssertEqual(writes[1].jsonBody["remindStart"] as? Bool, true)
        capture("YoungReminder")
        back()
        back()
        open("My Activities")
        assertText("Science Communication Workshop")
        assertText("Deadline")
        capture("MyActivities")
    }

    @MainActor
    func testUnreadReminderRefreshAndOrganizerUnfollow() throws {
        app.launch()
        openYoung()
        open("Notifications")
        open("Unread only")
        let notifications = "/api/workspace/young-notifications"
        waitForRequest("GET", notifications, query: ["unread": "true"])
        assertText("Workshop reminder")
        assertText("This activity starts within an hour.")
        capture("YoungNotifications")
        let markRead = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
            "young.notification.\(YoungCampusHTTPState.notificationID)", "Mark as read")).firstMatch
        reveal(markRead)
        XCTAssertTrue(markRead.waitForExistence(timeout: 10))
        markRead.tap()
        waitForRequest("POST", "\(notifications)/\(YoungCampusHTTPState.notificationID)/read")
        assertText("No unread reminders")
        back()
        open("Followed Organizers")
        openText("Student Science Association")
        let followPath = "/api/workspace/young-organizer-subscriptions/\(YoungCampusHTTPState.organizerID)"
        waitForRequest("GET", followPath)
        toggle("young.follow.enabled")
        waitForRequest("PUT", followPath)
        XCTAssertEqual(fixture.requests.last { $0.method == "PUT" && $0.path == followPath }?.jsonBody["subscribed"] as? Bool, false)
        assertText("Following this organizer does not subscribe you to its activities.")
        capture("YoungOrganizer")
        back()
        assertText("No Followed Organizers")
    }

    @MainActor
    func testActivityCalendarDisplaysConflictsAndDistinguishesRegistrationWindows() throws {
        app.launch()
        openYoung()
        open("Activity Calendar")
        waitForRequest("GET", "/api/workspace/calendar/events")
        assertText("Calendar conflict")
        capture("YoungCalendar")
        open("Registration window")
        assertText("Switch to activity times to check calendar conflicts.")
        let activityReads = fixture.requests.filter { $0.path == "/api/catalog/young-events" }
        XCTAssertTrue(activityReads.contains { $0.query["timeBasis"] == "activity" })
        waitForRequest("GET", "/api/catalog/young-events", query: ["timeBasis": "registration"])
    }

    @MainActor
    func testPublicationReadRetrySiblingAndSourceFilters() throws {
        app.launch()
        selectDiscover()
        open("discover_publications")
        waitForRequest("GET", "/api/publications")
        XCTAssertNil(fixture.requests.first { $0.path == "/api/publications" }?.query["fold"])
        assertText("Autumn Science Festival")
        capture("Publications")
        let detailPath = "/api/publications/\(YoungCampusHTTPState.publicationID)"
        fixture.failNextRequest(method: "GET", path: detailPath)
        open("publication.row.\(YoungCampusHTTPState.publicationID)")
        assertText("Workspace fixture unavailable")
        open("publication.detail.retry")
        assertText("open laboratories")
        capture("PublicationDetail")
        assertText("festival-program.pdf")
        openText("Student Office")
        waitForRequest("GET", "/api/publications/\(YoungCampusHTTPState.siblingID)")
        back()
        back()
        open("publications.sources")
        waitForRequest("GET", "/api/publications/sources")
        assertText("USTC News")
        assertText("Student Office")
        assertText("news.ustc.edu.cn")
        assertText("office.ustc.edu.cn")
        capture("PublicationSources")
        open("publication.source.student-office")
        waitForRequest("GET", "/api/publications", query: ["source": "student-office"])
        assertText("Autumn Science Festival")
        open("publications.filters")
        toggle("publications.fold")
        toggle("Offices")
        open("publications.filters.apply")
        waitForRequest("GET", "/api/publications", query: ["source": "student-office", "organizationLevel": "office", "fold": "1"])
        capture("PublicationFilters")
    }

    @MainActor
    private func openYoung() {
        selectDiscover()
        open("Second Classroom")
    }

    @MainActor
    private func chooseFilter(_ field: String, value: String) {
        open("young.filters.\(field)")
        open(value)
    }

    @MainActor
    private func selectDiscover() {
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        } else {
            let tab = app.buttons["Tab.Discover"]
            if !tab.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 10))
                toggle.tap()
            }
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-m4-\(page)" + (app.frame.width > 700 ? "-iPad" : "")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func reveal(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 2)
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
        let button = app.buttons[id]
        reveal(button)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(id)", file: file, line: line)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, "Unavailable control: \(id)", file: file, line: line)
        button.tap()
    }

    @MainActor
    private func openText(_ text: String) {
        let label = app.staticTexts[text].firstMatch
        reveal(label)
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        label.tap()
    }

    @MainActor
    private func assertText(_ text: String) {
        let element = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        reveal(element)
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing text: \(text)")
    }

    @MainActor
    private func switchControl(_ id: String) -> XCUIElement {
        let outer = app.switches[id]
        reveal(outer)
        XCTAssertTrue(outer.waitForExistence(timeout: 10), "Missing switch: \(id)")
        return outer.switches.firstMatch.exists ? outer.switches.firstMatch : outer
    }

    @MainActor
    private func toggle(_ id: String) {
        let control = switchControl(id)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        control.tap()
    }

    @MainActor
    private func back() {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
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

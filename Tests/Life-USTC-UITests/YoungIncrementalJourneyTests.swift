import XCTest

final class YoungIncrementalJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, youngCampus: true)
        fixture.enableYoungIncrementalFixture()
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
        }
        let requests = XCTAttachment(string: fixture.requests.map {
            "\($0.method) \($0.path) \($0.query)"
        }.joined(separator: "\n"))
        requests.name = "incremental-page-requests"
        requests.lifetime = .keepAlways
        add(requests)
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testListShowsFirstBatchWhileSecondPageLoads() {
        verifyIncrementalLoading(screen: "Activities", evidence: "YoungList")
    }

    @MainActor
    func testCalendarShowsFirstBatchWhileSecondPageLoads() {
        verifyIncrementalLoading(screen: "Activity Calendar", evidence: "YoungCalendar")
    }

    @MainActor
    func testListKeepsFirstBatchAfterFailureAndContinuesTheUnfinishedPage() {
        verifyIncrementalLoading(screen: "Activities", evidence: "YoungListInterrupted", interrupted: true)
    }

    @MainActor
    func testCalendarKeepsFirstBatchAfterFailureAndContinuesTheUnfinishedPage() {
        verifyIncrementalLoading(screen: "Activity Calendar", evidence: "YoungCalendarInterrupted", interrupted: true)
    }

    @MainActor
    private func verifyIncrementalLoading(screen: String, evidence: String, interrupted: Bool = false) {
        app.launch()
        selectActivities()
        XCTAssertTrue(app.buttons["activities_list"].waitForExistence(timeout: 10))
        open(screen)
        waitUntil { self.fixture.heldYoungPages.count == 1 }
        XCTAssertEqual(fixture.heldYoungPages.first?.query["page"], "2")
        XCTAssertEqual(fixture.heldYoungPages.first?.query["pageSize"], "100")
        XCTAssertEqual(fixture.requests.filter { $0.path == "/api/catalog/young-events" }.count, 2)
        XCTAssertTrue(app.activityIndicators.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[YoungIncrementalHTTPState.firstTitle].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No activities"].exists)
        capture("after-incremental-\(evidence)-Pending")

        fixture.releaseYoungPages(status: interrupted ? 503 : 200)
        if interrupted {
            let continueLoading = app.buttons["young.continueLoading"]
            XCTAssertTrue(continueLoading.waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[YoungIncrementalHTTPState.firstTitle].exists)
            XCTAssertFalse(app.activityIndicators.firstMatch.exists)
            XCTAssertFalse(app.staticTexts["No activities"].exists)
            capture("after-incremental-\(evidence)-Failure")
            continueLoading.tap()
            waitUntil { self.fixture.requests.filter { $0.path == "/api/catalog/young-events" }.count == 3 }
            waitUntil { !continueLoading.exists }
        }
        XCTAssertTrue(app.staticTexts[YoungIncrementalHTTPState.firstTitle].waitForExistence(timeout: 10))
        waitUntil { !self.app.activityIndicators.firstMatch.exists }
        XCTAssertTrue(fixture.heldYoungPages.isEmpty)
        XCTAssertFalse(app.buttons["young.continueLoading"].exists)
        XCTAssertFalse(app.staticTexts["Some activities have not loaded yet."].exists)
        let requests = fixture.requests.filter { $0.path == "/api/catalog/young-events" }
        XCTAssertEqual(requests.map { $0.query["page"] }, interrupted ? ["1", "2", "2"] : ["1", "2"])
        if interrupted { XCTAssertEqual(requests[1].query, requests[2].query) }
        capture("after-incremental-\(evidence)-Complete")
        let finalBatch = app.staticTexts[YoungIncrementalHTTPState.finalTitle]
        for _ in 0..<40 {
            if finalBatch.exists && finalBatch.isHittable { break }
            let list = app.collectionViews.firstMatch
            if finalBatch.exists {
                let viewport = list.frame.intersection(app.frame)
                let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let distance = min(120, max(-120, viewport.midY - finalBatch.frame.midY))
                let end = start.withOffset(CGVector(dx: 0, dy: distance))
                start.press(forDuration: 0.05, thenDragTo: end)
            } else {
                list.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(finalBatch.waitForExistence(timeout: 10), "The second page must become visible")
        XCTAssertTrue(finalBatch.isHittable)
    }

    @MainActor
    private func selectActivities() {
        PrimaryNavigation.select("Activities", index: 3, in: app)
    }

    @MainActor
    private func open(_ name: String) {
        let button = app.buttons[name]
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing control: \(name)")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        button.tap()
    }

    @MainActor
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name + (app.frame.width > 700 ? "-iPad" : "-iPhone")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }
}

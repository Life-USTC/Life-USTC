import XCTest

/// Native UI integration with a stateful wire peer, independent of production OAuth.
final class WorkspaceJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let todoID = WorkspaceTodoHTTPState.initialTodoID
    private let homeworkID = WorkspaceLearningHTTPState.pendingHomeworkID
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true)
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
    func testHomeShowsActionableGroupsAndTypedDestinations() throws {
        app.launch()
        waitForRequest("GET", "/api/workspace/overview/actionable", query: ["locale": "en-us"])
        XCTAssertTrue(app.staticTexts["Happening now"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Needs attention"].exists)
        capture("Home")
        open("workspace_event_schedule:901")
        waitForRequest("GET", "/api/catalog/sections/42")
        XCTAssertTrue(app.buttons["section_subscribe"].waitForExistence(timeout: 10))
        back()

        open("home_deadlines_today")
        XCTAssertTrue(app.staticTexts["No pending deadlines"].waitForExistence(timeout: 10))
        back()
        open("home_deadlines_nextThreeDays")
        open("workspace_event_homework_due:\(homeworkID)")
        waitForRequest("GET", "/api/community/section-homeworks/\(homeworkID)")
        XCTAssertTrue(app.staticTexts["Calculus problem set"].waitForExistence(timeout: 10))
        back()
        back()
        open("home_deadlines_allPending")
        open("workspace_event_todo_due:\(todoID)")
        XCTAssertTrue(app.staticTexts["todo.detail.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["todo.detail.title"].label, "Review Calculus notes")
    }

    @MainActor
    func testTodoCreateDeleteRefreshesHomeAndCalendar() throws {
        app.launch()
        selectTab("Calendar", index: 1)
        waitForRequest("GET", "/api/workspace/calendar/events")
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let tomorrow = String(formatter.string(from: Date().addingTimeInterval(86400)).prefix(10))
        let day = app.segmentedControls["workspace_calendar_mode"].buttons["Day"]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()
        open("Next period")
        waitForRequest("GET", "/api/workspace/calendar/events",
                       query: ["dateFrom": tomorrow, "dateTo": tomorrow])
        let originalCalendarReads = requestCount("GET", "/api/workspace/calendar/events")
        selectTab("Home", index: 0)
        open("home_todos")
        XCTAssertTrue(app.buttons["todo.edit.\(todoID)"].waitForExistence(timeout: 10))
        capture("Todos")
        open("todo.create")
        replaceText("todo.title", old: "", new: "Prepare native journey notes")
        replaceText("todo.notes", old: "", new: "Created through the app")
        capture("TodoEditor")
        setDueDate(true)
        open("todo.save")
        waitForRequest("POST", "/api/workspace/todos")
        let created = try XCTUnwrap(fixture.workspaceTodos.first { $0["title"] as? String == "Prepare native journey notes" })
        let id = try XCTUnwrap(created["id"] as? String)
        XCTAssertNotNil(created["dueAt"] as? String)
        XCTAssertEqual(created["content"] as? String, "Created through the app")
        XCTAssertTrue(app.buttons["todo.edit.\(id)"].waitForExistence(timeout: 10))
        back()
        open("workspace_event_todo_due:\(id)")
        XCTAssertTrue(app.staticTexts["todo.detail.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["todo.detail.title"].label, "Prepare native journey notes")
        capture("TodoDetail")
        selectTab("Calendar", index: 1)
        open("workspace_event_todo_due:\(id)")
        XCTAssertGreaterThan(requestCount("GET", "/api/workspace/calendar/events"), originalCalendarReads)
        open("todo.detail.delete")
        let confirmation = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Delete", "todo.detail.delete"
        )).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        confirmation.tap()
        waitForRequest("DELETE", "/api/workspace/todos/\(id)")
        XCTAssertTrue(app.staticTexts["Todo Unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(fixture.workspaceTodos.contains { $0["id"] as? String == id })
        back()
        XCTAssertFalse(app.buttons["workspace_event_todo_due:\(id)"].exists)
    }

    @MainActor
    func testTodoEditClearsOptionalFieldsAndPreservesFailedDraft() throws {
        fixture.failNextRequest(method: "PATCH", path: "/api/workspace/todos/\(todoID)")
        app.launch()
        open("home_todos")
        open("todo.edit.\(todoID)")
        replaceText("todo.title", old: "Review Calculus notes", new: "Review revised notes")
        replaceText("todo.notes", old: "Prepare questions for the next seminar.", new: "")
        setDueDate(false)
        open("todo.save")
        XCTAssertTrue(app.staticTexts["todo.save.error"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["todo.title"].value as? String, "Review revised notes")
        XCTAssertEqual(fixture.workspaceTodos.first { $0["id"] as? String == todoID }?["title"] as? String,
                       "Review Calculus notes")
        let failed = try XCTUnwrap(fixture.requests.first { $0.method == "PATCH" && $0.path.hasSuffix(todoID) })
        XCTAssertTrue(failed.jsonBody["content"] is NSNull)
        XCTAssertTrue(failed.jsonBody["dueAt"] is NSNull)
        open("todo.save.retry")
        XCTAssertTrue(app.buttons["todo.edit.\(todoID)"].waitForExistence(timeout: 10))
        let saved = try XCTUnwrap(fixture.workspaceTodos.first { $0["id"] as? String == todoID })
        XCTAssertEqual(saved["title"] as? String, "Review revised notes")
        XCTAssertTrue(saved["content"] is NSNull)
        XCTAssertTrue(saved["dueAt"] is NSNull)
        XCTAssertEqual(requestCount("PATCH", "/api/workspace/todos/\(todoID)"), 2)
    }

    @MainActor
    func testTodoCompletionFailurePreservesPendingUntilRetry() throws {
        fixture.failNextRequest(method: "PATCH", path: "/api/workspace/todos/\(todoID)")
        app.launch()
        open("home_todos")
        open("todo.complete.\(todoID)")
        XCTAssertTrue(app.staticTexts["todo.mutation.error"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["todo.edit.\(todoID)"].exists)
        XCTAssertEqual(fixture.workspaceTodos.first { $0["id"] as? String == todoID }?["completed"] as? Bool, false)
        open("todo.mutation.retry")
        waitUntil { self.fixture.workspaceTodos.first { $0["id"] as? String == self.todoID }?["completed"] as? Bool == true }
        XCTAssertTrue(app.staticTexts["No Todos"].waitForExistence(timeout: 10))
        app.segmentedControls["todo.status"].buttons["Completed"].tap()
        XCTAssertTrue(app.buttons["todo.edit.\(todoID)"].waitForExistence(timeout: 10))
        XCTAssertEqual(requestCount("PATCH", "/api/workspace/todos/\(todoID)"), 2)
    }

    @MainActor
    func testHomeworkCompletionUsesServerTimestampAndTAHasNoManualAction() throws {
        let path = "/api/workspace/homeworks/\(homeworkID)/completion"
        fixture.failNextRequest(method: "PUT", path: path)
        app.launch()
        open("home_homeworks")
        waitForRequest("GET", "/api/workspace/homeworks")
        app.segmentedControls["homework.status"].buttons["All"].tap()
        let taID = WorkspaceLearningHTTPState.taHomeworkID
        XCTAssertFalse(app.buttons["homework.complete.\(taID)"].exists)
        XCTAssertTrue(app.buttons["homework.row.\(homeworkID)"].waitForExistence(timeout: 10))
        capture("Homeworks")
        open("homework.complete.\(homeworkID)")
        XCTAssertTrue(app.staticTexts["Workspace fixture unavailable"].waitForExistence(timeout: 10))
        XCTAssertTrue(fixture.workspaceHomeworks.first { $0["id"] as? String == homeworkID }?["completion"] is NSNull)
        open("homework.mutation.retry")
        waitUntil {
            let homework = self.fixture.workspaceHomeworks.first { $0["id"] as? String == self.homeworkID }
            return (homework?["completion"] as? [String: Any])?["completedAt"] as? String == WorkspaceLearningHTTPState.completedAt
        }
        open("homework.row.\(homeworkID)")
        assertText("10:03")
        capture("HomeworkDetail")
        XCTAssertEqual(requestCount("PUT", path), 2)
        XCTAssertEqual(fixture.requests.first { $0.method == "PUT" && $0.path == path }?.jsonBody["completed"] as? Bool, true)
        back()
        open("homework.row.\(taID)")
        assertText("No completion is required for your teaching-assistant subscription.")
        XCTAssertFalse(app.buttons["homework.detail.complete"].exists)
        let request = try XCTUnwrap(fixture.requests.first { $0.path == "/api/workspace/homeworks" })
        XCTAssertTrue(request.headers["accept-language"]?.lowercased().hasPrefix("en") == true,
                      "The real URLSession homework request should carry the app locale")
    }

    @MainActor
    func testSubscribedExamsRetainUnknownDatesAndLinkUsingSectionJWID() throws {
        app.launch()
        open("home_exams")
        waitForRequest("GET", "/api/workspace/exams", query: ["includeDateUnknown": "true"])
        XCTAssertTrue(app.buttons["workspace.exam.\(WorkspaceLearningHTTPState.datedExamID)"].waitForExistence(timeout: 10))
        capture("Exams")
        open("workspace.exam.\(WorkspaceLearningHTTPState.undatedExamID)")
        assertText("Date unavailable")
        assertText("Time unavailable")
        assertText("Exam Hall 2")
        capture("ExamDetail")
        open("workspace.exam.detail.section")
        waitForRequest("GET", "/api/catalog/sections/42")
        XCTAssertTrue(app.buttons["section_subscribe"].waitForExistence(timeout: 10))
        XCTAssertFalse(fixture.requests.contains { $0.path == "/api/catalog/sections/7" })
    }

    @MainActor
    func testCalendarFeedCopyAndSignOutClearMountedWorkspace() throws {
        app.launch()
        open("home_todos")
        XCTAssertTrue(app.buttons["todo.edit.\(todoID)"].waitForExistence(timeout: 10))
        selectTab("Calendar", index: 1)
        XCTAssertTrue(app.buttons["workspace_event_schedule:901"].waitForExistence(timeout: 10))
        capture("Calendar")
        open("calendar_feed")
        open("calendar_feed_copy")
        XCTAssertTrue(app.buttons["calendar_feed_copy"].label.contains("Copied"))
        capture("CalendarFeed")
        XCTAssertTrue(fixture.requests.allSatisfy { $0.method == "GET" })
        let request = try XCTUnwrap(fixture.requests.first { $0.path == "/api/workspace/calendar/events" })
        XCTAssertTrue(request.headers["accept-language"]?.lowercased().hasPrefix("en") == true,
                      "The real URLSession calendar request should carry the app locale")
        selectTab("Account", index: 3)
        open("settings_server_account")
        open("Sign Out")
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 10))
        let privateReads = fixture.requests.filter { $0.path.hasPrefix("/api/workspace/") }.count
        selectTab("Home", index: 0)
        open("home_todos")
        XCTAssertTrue(app.staticTexts["Sign In Required"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["todo.edit.\(todoID)"].exists)
        selectTab("Calendar", index: 1)
        XCTAssertFalse(app.buttons["workspace_event_schedule:901"].exists)
        XCTAssertFalse(app.buttons["calendar_feed_copy"].exists)
        XCTAssertEqual(fixture.requests.filter { $0.path.hasPrefix("/api/workspace/") }.count, privateReads)
    }

    @MainActor
    private func capture(_ page: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "after-workspace-\(page)" + (app.frame.width > 700 ? "-iPad" : "-iPhone")
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func open(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
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
    private func replaceText(_ id: String, old: String, new: String) {
        let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        if !old.isEmpty {
            XCTAssertEqual(field.value as? String, old)
            field.press(forDuration: 1)
            let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
            XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
            selectAll.tap()
        }
        field.typeText(new.isEmpty ? XCUIKeyboardKey.delete.rawValue : new)
        if new.isEmpty {
            XCTAssertTrue(["", "Notes"].contains(field.value as? String ?? "<missing>"))
        } else {
            XCTAssertEqual(field.value as? String, new)
        }
    }

    @MainActor
    private func setDueDate(_ enabled: Bool) {
        let row = app.switches["todo.hasDueDate"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let value = enabled ? "1" : "0"
        if row.value as? String != value {
            let control = row.switches.firstMatch
            (control.exists ? control : row).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    @MainActor
    private func back() {
        let button = app.navigationBars.buttons.matching(NSPredicate(format: "NOT (label IN %@)", sidebarLabels)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    @MainActor
    private func selectTab(_ name: String, index: Int) {
        if app.tabBars.firstMatch.exists {
            app.tabBars.firstMatch.buttons.element(boundBy: index).tap()
        } else {
            let tab = app.buttons["Tab.\(name)"]
            if !tab.isHittable {
                let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 10))
                toggle.tap()
            }
            XCTAssertTrue(tab.isHittable)
            tab.tap()
        }
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

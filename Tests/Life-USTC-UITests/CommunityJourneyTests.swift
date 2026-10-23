import XCTest

/// Native UI integration with a stateful wire peer, independent of production OAuth.
final class CommunityJourneyTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private let sidebarLabels = ["Show Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, community: true)
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
    func testCommentEditPreservesAttachmentAndCreateRetryOpensFocusedThread() throws {
        app.launch()
        openSection()
        open("Comments")
        waitForRequest("GET", "/api/community/comments", query: ["targetId": "7"])
        assertText("Bring your questions to the seminar.")
        capture("Comments")
        open("Comment actions")
        open("Edit")
        replaceText("comment_body", old: "Bring your questions to the seminar.", new: "Bring a worked example to the seminar.")
        open("comment_submit")
        waitForRequest("PATCH", "/api/community/comments/\(CommunityHTTPState.commentID)")
        assertText("Bring a worked example to the seminar.")
        let edit = try XCTUnwrap(fixture.requests.first { $0.method == "PATCH" && $0.path.hasPrefix("/api/community/comments/") })
        XCTAssertEqual(edit.jsonBody["attachmentIds"] as? [String], [CommunityHTTPState.uploadID])

        fixture.failNextRequest(method: "POST", path: "/api/community/comments")
        open("comment_compose")
        replaceText("comment_body", old: "", new: "I can share my worked example.")
        open("comment_submit")
        assertText("Workspace fixture unavailable")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "comment_body").firstMatch.value as? String,
                       "I can share my worked example.")
        open("comment_submit")
        assertText("I can share my worked example.")
        XCTAssertEqual(fixture.communityComments.count, 2)
        let create = try XCTUnwrap(fixture.requests.last { $0.method == "POST" && $0.path == "/api/community/comments" })
        XCTAssertEqual(create.jsonBody["targetId"] as? String, "7")
        XCTAssertNil(create.jsonBody["sectionId"])
        XCTAssertNil(create.jsonBody["sectionJwId"])

        app.buttons["View comment thread"].firstMatch.tap()
        waitForRequest("GET", "/api/community/comments/\(CommunityHTTPState.commentID)")
        open("Reply")
        replaceText("comment_body", old: "", new: "I will prepare a second example.")
        open("comment_submit")
        assertText("I will prepare a second example.")
        let reply = try XCTUnwrap(fixture.requests.last { $0.method == "POST" && $0.path == "/api/community/comments" })
        XCTAssertEqual(reply.jsonBody["parentId"] as? String, CommunityHTTPState.commentID)
        XCTAssertEqual(reply.jsonBody["targetId"] as? String, "7")
        capture("Thread")
    }

    @MainActor
    func testCommentAttachmentPreviewPublicAuthorProfileAndDeletion() throws {
        app.launch()
        openSection()
        open("Comments")
        XCTAssertTrue(attachmentButton.waitForExistence(timeout: 10))
        attachmentButton.tap()
        waitForRequest("GET", "/api/workspace/uploads/\(CommunityHTTPState.uploadID)/download")
        let closePreview = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
        XCTAssertTrue(closePreview.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews.containing(NSPredicate(format: "label CONTAINS %@",
                       "Seminar preparation notes from fixture.")).firstMatch.waitForExistence(timeout: 10))
        capture("Attachment")
        closePreview.tap()
        open("Fixture Student")
        waitForRequest("GET", "/api/community/users/fixture-student")
        assertText("Total Contributions")
        open("contribution_day_2026-10-23")
        assertText("2026-10-23: 3 contributions")
        capture("Profile")
        back()
        open("Comment actions")
        open("Delete")
        let confirmation = app.buttons["Delete"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        confirmation.tap()
        waitForRequest("DELETE", "/api/community/comments/\(CommunityHTTPState.commentID)")
        XCTAssertTrue(app.staticTexts["No Comments"].waitForExistence(timeout: 10))
        XCTAssertTrue(fixture.communityComments.isEmpty)
    }

    @MainActor
    func testDescriptionFailureKeepsDraftAndRetryShowsCanonicalHistory() throws {
        fixture.failNextRequest(method: "POST", path: "/api/community/descriptions")
        app.launch()
        openSection()
        capture("Section")
        open("section_description")
        waitForRequest("GET", "/api/community/descriptions", query: ["targetType": "section", "sectionJwId": "42"])
        open("description.edit")
        replaceText("description.draft", old: "Shared seminar preparation notes.", new: "Read the examples before the seminar.")
        open("description.save")
        XCTAssertTrue(app.staticTexts["description.save.error"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textViews["description.draft"].value as? String, "Read the examples before the seminar.")
        open("description.save.retry")
        assertText("Read the examples before the seminar.")
        assertText("Edit History")
        open("View changes")
        assertText("Shared seminar preparation notes.")
        capture("Description")
        let write = try XCTUnwrap(fixture.requests.first { $0.method == "POST" && $0.path == "/api/community/descriptions" })
        XCTAssertEqual(write.jsonBody["sectionJwId"] as? Int, 42)
        XCTAssertEqual(write.jsonBody["content"] as? String, "Read the examples before the seminar.")
    }

    @MainActor
    func testSharedHomeworkCreateEditDeleteKeepsAuditHistory() throws {
        app.launch()
        openSection()
        open("Shared Homework")
        waitForRequest("GET", "/api/community/section-homeworks", query: ["sectionJwId": "42", "includeDeleted": "true"])
        open("section.homeworks.create")
        replaceText("homework.editor.title", old: "", new: "Present a worked example")
        replaceText("homework.editor.description", old: "", new: "Prepare a short explanation.")
        open("homework.editor.save")
        waitForRequest("POST", "/api/community/section-homeworks")
        let created = try XCTUnwrap(fixture.communityHomeworks.first { $0["title"] as? String == "Present a worked example" })
        let id = try XCTUnwrap(created["id"] as? String)
        XCTAssertTrue(homeworkActions(id).waitForExistence(timeout: 10))
        homeworkActions(id).tap()
        open("Edit")
        replaceText("homework.editor.title", old: "Present a worked example", new: "Present two worked examples")
        open("homework.editor.save")
        waitForRequest("PATCH", "/api/community/section-homeworks/\(id)")
        assertText("Present two worked examples")
        capture("Homework")
        homeworkActions(id).tap()
        open("Delete")
        let confirmation = app.buttons["Delete"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        confirmation.tap()
        waitForRequest("DELETE", "/api/community/section-homeworks/\(id)")
        let toggle = app.switches["section.homeworks.showDeleted"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let control = toggle.switches.firstMatch
        (control.exists ? control : toggle).tap()
        assertText("Deleted")
        XCTAssertFalse(homeworkActions(id).exists)
        open("section.homeworks.history")
        waitForRequest("GET", "/api/community/section-homeworks/audit", query: ["sectionJwId": "42"])
        assertText("Present two worked examples")
        capture("HomeworkHistory")
        XCTAssertEqual(fixture.requests.filter { $0.method == "POST" && $0.path == "/api/community/section-homeworks" }.count, 1)
    }

    @MainActor
    func testOwnedFilesRenameFailureRetryAndDeleteRefreshQuota() throws {
        fixture.failNextRequest(method: "PATCH", path: "/api/workspace/uploads/\(CommunityHTTPState.uploadID)")
        app.launch()
        selectTab("Account", index: 3)
        capture("Account")
        captureNamed("before-m5-Settings")
        open("settings_server_account")
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
        captureNamed("before-m5-ServerAccount")
        back()
        open("settings_my_files")
        waitForRequest("GET", "/api/workspace/uploads")
        capture("Files")
        open("owned_file_rename_\(CommunityHTTPState.uploadID)")
        let filename = app.alerts.textFields.firstMatch
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Seminar notes.txt".count) + "Revised seminar notes.txt")
        app.alerts.buttons["Save"].tap()
        open("owned_files_mutation_retry")
        assertText("Revised seminar notes.txt")
        XCTAssertEqual(fixture.communityUploads.first?["filename"] as? String, "Revised seminar notes.txt")
        open("owned_file_delete_\(CommunityHTTPState.uploadID)")
        let confirmation = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Delete", "owned_file_delete_\(CommunityHTTPState.uploadID)")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        confirmation.tap()
        waitForRequest("DELETE", "/api/workspace/uploads/\(CommunityHTTPState.uploadID)")
        XCTAssertTrue(app.staticTexts["No Files"].waitForExistence(timeout: 10))
        XCTAssertTrue(fixture.communityUploads.isEmpty)
        XCTAssertEqual(fixture.requests.filter { $0.method == "PATCH" && $0.path.hasPrefix("/api/workspace/uploads/") }.count, 2)
    }

    @MainActor
    func testAnonymousCommentAttachmentExplainsSignInWithoutDownloading() throws {
        app.launchEnvironment.removeValue(forKey: "UI_TEST_SERVER_ACCESS_TOKEN")
        app.launch()
        open("home_catalog")
        open("catalog_section_42")
        open("Comments")
        assertText("Bring your questions to the seminar.")
        let preview = attachmentButton
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertFalse(preview.isEnabled)
        XCTAssertTrue(app.buttons["Sign in to download attachments"].exists)
        XCTAssertFalse(fixture.requests.contains { $0.path.hasSuffix("/download") })
        XCTAssertFalse(app.buttons["comment_compose"].exists)
        capture("AnonymousComments")
    }

    @MainActor
    func testAnonymousHiddenCommentsShowVisibilityExplanationAndSignIn() throws {
        fixture.hideCommunityComments()
        app.launchEnvironment.removeValue(forKey: "UI_TEST_SERVER_ACCESS_TOKEN")
        app.launch()
        open("home_catalog")
        open("catalog_section_42")
        open("Comments")
        XCTAssertTrue(app.staticTexts["No Visible Comments"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Some comments are hidden from your view."].exists)
        XCTAssertTrue(app.staticTexts["1 hidden comments"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
        XCTAssertFalse(app.staticTexts["Be the first to comment."].exists)
        capture("HiddenComments")
    }

    @MainActor
    private var attachmentButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seminar notes.txt")).firstMatch
    }

    @MainActor
    private func homeworkActions(_ id: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                        "section.homeworks.row.\(id)", "Homework actions")).firstMatch
    }

    @MainActor
    private func openSection() {
        open("home_catalog")
        open("catalog_section_42")
        XCTAssertTrue(app.buttons["section_subscribe"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func capture(_ page: String) { captureNamed("after-m3-\(page)") }

    @MainActor
    private func captureNamed(_ name: String) {
        let deviceName = app.frame.width > 700 ? "-iPad" : ""
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name + deviceName
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
        // A multiline field's centre can position the caret before its text.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + new)
        if !new.isEmpty {
            waitUntil { field.value as? String == new }
            XCTAssertEqual(field.value as? String, new)
        }
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

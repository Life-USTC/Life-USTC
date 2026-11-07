
    // These cases run in a separate invocation after the original positive
    // case. They cannot add waiting or observations ahead of that case.
    @MainActor
    func testAccountDiagnosticRejectsVisibleBrowser() throws {
        launchAccount()
        try open("settings_server_account")
        try open("server_account_management")
        let applicationFrame = app.frame
        XCTAssertFalse(applicationFrame.isEmpty)
        try open("account_web_profile")
        waitForRequest("GET", "/account/settings/profile", timeout: 45)
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/account/settings/profile" })
        XCTAssertNil(request.headers["authorization"])
        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "BrowserView")).firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
        // Prove that the underlying page is present: absence alone is not the
        // intended reason for this negative control to reject return.
        let management = app.navigationBars["Account Management"]
        let page = app.buttons["account_web_profile"]
        XCTAssertTrue(management.exists)
        XCTAssertTrue(page.exists && page.isEnabled)
        XCTAssertFalse(page.frame.isEmpty)
        XCTAssertTrue(page.frame.intersects(applicationFrame))
        XCTAssertTrue(browser.exists && browser.isHittable)
        XCTAssertFalse(diagnosticReturnState(pageID: "account_web_profile", applicationFrame: applicationFrame),
                       "A still-open Safari must not be accepted as a completed return")
    }

    @MainActor
    func testAccountDiagnosticRejectsWrongPageAfterClose() throws {
        launchAccount()
        try open("settings_server_account")
        try open("server_account_management")
        let applicationFrame = app.frame
        XCTAssertFalse(applicationFrame.isEmpty)
        let previousReads = requestCount("GET", "/api/account/profile")
        try open("account_web_profile")
        waitForRequest("GET", "/account/settings/profile", timeout: 45)
        let request = try XCTUnwrap(fixture.requests.last { $0.path == "/account/settings/profile" })
        XCTAssertNil(request.headers["authorization"])
        /* CLOSE_CALL */
        waitUntil { self.requestCount("GET", "/api/account/profile") > previousReads }
        XCTAssertTrue(app.navigationBars["Account Management"].exists)
        XCTAssertFalse(app.buttons["account_web_diagnostic_missing_page"].exists)
        XCTAssertFalse(diagnosticReturnState(pageID: "account_web_diagnostic_missing_page", applicationFrame: applicationFrame),
                       "A successful close must not make a missing page satisfy the return predicate")
    }

    @MainActor
    private func diagnosticReturnState(pageID: String, applicationFrame: CGRect) -> Bool {
        let management = app.navigationBars["Account Management"]
        let page = app.buttons[pageID]
        let browser = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "BrowserView")).firstMatch
        return /* RETURN_EXPRESSION */
    }

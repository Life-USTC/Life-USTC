import XCTest
import UIKit

/// Supplemental acceptance only: the original 71-case UI phase does not select this class.
final class CatalogIdentityAcceptanceTests: XCTestCase {
    private var fixture: ServerJourneyHTTPFixture!
    private var app: XCUIApplication!
    private var language = "en"
    private var chinese: Bool { language == "zh-Hans" }
    private var courseName: String { chinese ? CatalogIdentityAcceptanceFacts.courseCn : CatalogIdentityAcceptanceFacts.courseEn }
    private var teacherName: String { chinese ? CatalogIdentityAcceptanceFacts.teacherCn : CatalogIdentityAcceptanceFacts.teacherEn }
    private var courseCodeLabel: String { (chinese ? "课程代码: " : "Course code: ") + CatalogIdentityAcceptanceFacts.courseCode }
    private var sectionCodeLabel: String { (chinese ? "教学班代码: " : "Section code: ") + CatalogIdentityAcceptanceFacts.sectionCode }
    private var semesterLabel: String { chinese ? "学期: 2026 Fall" : "Semester: 2026 Fall" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = ServerJourneyHTTPFixture(workspace: true, catalogHistory: true, catalogIdentityAcceptance: true)
        fixture.includeHistoricalSubscription()
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SERVER_URL"] = try fixture.start().absoluteString
        app.launchEnvironment["UI_TEST_SKIP_ONBOARDING"] = "1"
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 { capture("Failure") }
        let requests = XCTAttachment(string: fixture.requests.map {
            "\($0.method) \($0.path) \($0.query) \(String(data: $0.body, encoding: .utf8) ?? "")"
        }.joined(separator: "\n"))
        requests.name = "catalog-identity-requests"
        requests.lifetime = .keepAlways
        add(requests)
        app.terminate()
        fixture.stop()
    }

    @MainActor
    func testEnglishIdentityAcrossNativeAdoptionPoints() throws {
        try identityJourney(language: "en", locale: "en_US")
    }

    @MainActor
    func testChineseIdentityAcrossNativeAdoptionPoints() throws {
        try identityJourney(language: "zh-Hans", locale: "zh_CN")
    }

    @MainActor
    private func identityJourney(language: String, locale: String) throws {
        self.language = language
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "UI_TEST_SKIP_ONBOARDING"]

        // Anonymous browsing still offers authentication for this exact current section.
        launch(signedIn: false)
        try open("home_catalog")
        try sectionRow("catalog_section_42", page: "CatalogSection")
        try open("catalog_section_42")
        try detailIdentity(page: "AnonymousSection")
        let signIn = app.buttons["section_sign_in"]
        reveal(signIn)
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        XCTAssertTrue(signIn.isEnabled && signIn.isHittable)
        capture("AnonymousSignIn")
        XCTAssertFalse(fixture.requests.contains { $0.headers["authorization"] != nil })

        launch(signedIn: true)
        try open("home_catalog")
        try chooseCatalog(chinese ? "课程" : "Courses")
        let course = app.buttons["catalog_course_1001"]
        try identity(course, fields: [CatalogIdentityAcceptanceFacts.courseCode, courseName])
        try captureIdentity(course, labels: [courseCodeLabel, courseName], page: "CourseCatalog")
        try open("catalog_course_1001")
        try text(courseName)
        try text(courseCodeLabel)
        let courseHeader = app.collectionViews.cells.containing(NSPredicate(format: "label == %@", courseCodeLabel))
        XCTAssertEqual(courseHeader.count, 1)
        try captureIdentity(courseHeader.element, labels: [courseCodeLabel, courseName], page: "CourseDetail")
        try sectionRow("catalog_section_42", page: "CourseHistory")
        try open("catalog_section_42")
        try detailIdentity(page: "SectionDetail")
        let role = app.buttons["section_kind"]
        reveal(role)
        XCTAssertTrue(role.waitForExistence(timeout: 10))
        XCTAssertTrue(role.label.contains(chinese ? "修读" : "Enrolled"))
        capture("SectionRole")
        try back()
        try back()
        try chooseCatalog(chinese ? "教师" : "Teachers")
        try open("catalog_teacher_3")
        try sectionRow("catalog_section_42", page: "TeacherHistory")
        try open("catalog_section_44")
        let fallback = app.collectionViews.staticTexts.matching(NSPredicate(format: "label == %@", CatalogIdentityAcceptanceFacts.historicalCode)).firstMatch
        reveal(fallback)
        XCTAssertTrue(fallback.waitForExistence(timeout: 10))
        XCTAssertEqual(fallback.label, CatalogIdentityAcceptanceFacts.historicalCode)
        XCTAssertEqual(app.collectionViews.staticTexts.matching(NSPredicate(format: "label == %@", CatalogIdentityAcceptanceFacts.historicalCode)).count, 1, "The fallback appears once inside section content, excluding its navigation title")
        XCTAssertTrue(app.otherElements["section_historical"].exists || app.staticTexts["section_historical"].exists)
        XCTAssertFalse(app.buttons["section_subscribe"].exists)
        XCTAssertFalse(app.buttons["section_sign_in"].exists)
        // The native identity cell contains only its fallback; independent schedule teachers remain valid.
        let identityCells = app.collectionViews.cells.containing(NSPredicate(format: "label == %@", CatalogIdentityAcceptanceFacts.historicalCode))
        XCTAssertEqual(identityCells.count, 1)
        XCTAssertEqual(identityCells.element.staticTexts.count, 1, "No course, teachers, or semester may be invented inside the identity")
        XCTAssertEqual(identityCells.element.staticTexts.element.label, CatalogIdentityAcceptanceFacts.historicalCode)
        try captureIdentity(identityCells.element, labels: [CatalogIdentityAcceptanceFacts.historicalCode], page: "MissingContextHistoricalSection")
        let scheduleTeacher = app.buttons["section_schedule_901_teacher_3"]
        reveal(scheduleTeacher)
        XCTAssertTrue(scheduleTeacher.waitForExistence(timeout: 10))
        XCTAssertTrue(scheduleTeacher.isHittable)
        XCTAssertTrue(scheduleTeacher.label.contains(teacherName), "The independent schedule teacher is retained")
        try captureIdentity(scheduleTeacher, labels: [teacherName], page: "HistoricalScheduleTeacher")

        launch(signedIn: true)
        try open("home_subscriptions")
        try sectionRow("subscription_42", page: "Subscriptions")
        try open("subscription_42")
        try detailIdentity(page: "SubscribedSection")
        try back()
        try open("subscriptions_import_codes")
        try open("subscription_import_semester")
        try open("2026 Fall")
        let input = app.textViews["subscription_import_input"]
        reveal(input)
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText(CatalogIdentityAcceptanceFacts.courseCode)
        let typed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", CatalogIdentityAcceptanceFacts.courseCode), object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [typed], timeout: 10), .completed)
        try open("subscription_import_preview")
        let preview = app.switches["subscription_import_section_7"]
        try identity(preview, fields: [courseName, teacherName, CatalogIdentityAcceptanceFacts.sectionCode, "2026 Fall"])
        XCTAssertFalse(preview.isEnabled, "The same already-subscribed section is not appended again")
        XCTAssertEqual(preview.value as? String, "0")
        try captureIdentity(preview, labels: [courseName, teacherName, sectionCodeLabel, semesterLabel], page: "ImportPreview")
        let query = try XCTUnwrap(fixture.requests.last { $0.method == "POST" && $0.path == "/api/workspace/subscriptions/query" })
        XCTAssertEqual(query.jsonBody["codes"] as? [String], [CatalogIdentityAcceptanceFacts.courseCode])
        XCTAssertEqual(query.jsonBody["semesterId"] as? Int, 1)
        XCTAssertEqual(query.query["locale"], chinese ? "zh-cn" : "en-us")
        XCTAssertEqual(fixture.subscriptionKinds, [42: "regular", 43: "teaching_assistant", 44: "regular"])
        XCTAssertFalse(fixture.requests.contains { $0.method != "GET" && $0.path != "/api/workspace/subscriptions/query" })

        let firstPublicRequest = launch(signedIn: false)
        try open("home_catalog")
        let publicLink = app.buttons["catalog_public_schedule"].staticTexts.firstMatch
        try activate(publicLink)
        try sectionRow("public_schedule_1001_section", page: "PublicSchedule", teachers: teacherName + ", Ada Teacher")
        try open("public_schedule_1001_section")
        try detailIdentity(page: "PublicScheduleSection")
        let publicRequests = Array(fixture.requests.dropFirst(firstPublicRequest))
        XCTAssertTrue(publicRequests.contains { $0.path == "/api/catalog/schedules" && $0.query["locale"] == (chinese ? "zh-cn" : "en-us") })
        XCTAssertTrue(publicRequests.contains { $0.path == "/api/catalog/sections/42" })
        XCTAssertTrue(publicRequests.allSatisfy { $0.method == "GET" && $0.headers["authorization"] == nil })
    }

    @discardableResult
    @MainActor
    private func launch(signedIn: Bool) -> Int {
        app.terminate()
        let requestStart = fixture.requests.count
        if signedIn { app.launchEnvironment["UI_TEST_SERVER_ACCESS_TOKEN"] = ServerJourneyHTTPFixture.token }
        else { app.launchEnvironment.removeValue(forKey: "UI_TEST_SERVER_ACCESS_TOKEN") }
        app.launch()
        return requestStart
    }

    @MainActor
    private func chooseCatalog(_ title: String) throws {
        try activate(app.segmentedControls["catalog_kind"].buttons[title])
    }

    @MainActor
    private func sectionRow(_ id: String, page: String, teachers: String? = nil) throws {
        let teacherText = teachers ?? teacherName
        let row = app.buttons[id]
        try identity(row, fields: [courseName, teacherText, CatalogIdentityAcceptanceFacts.sectionCode, "2026 Fall"])
        try captureIdentity(row, labels: [courseName, teacherText, sectionCodeLabel, semesterLabel], page: page)
    }

    @MainActor
    private func detailIdentity(page: String) throws {
        try text(courseName)
        try text(teacherName)
        try text(sectionCodeLabel)
        try text(semesterLabel)
        let header = app.collectionViews.cells.containing(NSPredicate(format: "label == %@", sectionCodeLabel))
        XCTAssertEqual(header.count, 1)
        try captureIdentity(header.element, labels: [courseName, teacherName, sectionCodeLabel, semesterLabel], page: page)
    }

    @MainActor
    private func captureIdentity(_ container: XCUIElement, labels: [String], page: String) throws {
        for (index, label) in labels.enumerated() {
            try captureIdentityField(container, label: label, page: "\(page)-Field\(index + 1)")
        }
    }

    @MainActor
    private func captureIdentityField(_ container: XCUIElement, label: String, page: String) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        var covered: CGFloat = 0
        var previousSize = CGSize.zero
        var part = 0
        for action in 0...8 {
            let content = try container.snapshot()
            var pending = [content]
            var fields: [CGRect] = []
            while let node = pending.popLast() {
                if node.elementType == .staticText && node.label == label { fields.append(node.frame) }
                pending.append(contentsOf: node.children)
            }
            guard fields.count == 1 else { throw failure("Identity field must have one exact native StaticText: \(label)") }
            let target = fields[0]
            guard !target.isEmpty, [target.minX, target.minY, target.width, target.height].allSatisfy(\.isFinite) else { throw failure("Invalid identity field geometry") }
            let application = try app.snapshot()
            guard !application.frame.isEmpty,
                  [application.frame.minX, application.frame.minY, application.frame.width, application.frame.height].allSatisfy(\.isFinite) else { throw failure("Invalid application geometry") }
            guard !content.frame.isEmpty,
                  [content.frame.minX, content.frame.minY, content.frame.width, content.frame.height].allSatisfy(\.isFinite) else { throw failure("Invalid native identity container geometry") }
            var left = max(content.frame.minX, application.frame.minX)
            var right = min(content.frame.maxX, application.frame.maxX)
            var chrome: [XCUIElementSnapshot] = []
            pending = application.children
            while let node = pending.popLast() {
                if [.navigationBar, .tabBar, .keyboard].contains(node.elementType), !node.frame.isEmpty {
                    let frame = node.frame
                    guard [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite) else { throw failure("Invalid native chrome geometry") }
                    if frame.intersects(application.frame) { chrome.append(node) }
                }
                pending.append(contentsOf: node.children)
            }
            for node in chrome where node.elementType == .tabBar && node.frame.height > node.frame.width {
                let frame = node.frame
                if frame.maxX > left && frame.minX < right {
                    if frame.midX < (left + right) / 2 { left = max(left, frame.maxX) }
                    else { right = min(right, frame.minX) }
                }
            }
            var top = application.frame.minY
            var bottom = application.frame.maxY
            for node in chrome {
                let frame = node.frame
                guard frame.maxX > left && frame.minX < right else { continue }
                if node.elementType == .tabBar && frame.height > frame.width { continue }
                if node.elementType == .navigationBar || (node.elementType == .tabBar && frame.midY < application.frame.midY) {
                    top = max(top, frame.maxY)
                } else { bottom = min(bottom, frame.minY) }
            }
            guard right > left, bottom > top + 32 else { throw failure("Native chrome or keyboard leaves no readable content pane") }
            let viewport = CGRect(x: left, y: top + 8, width: right - left, height: bottom - top - 16)
            guard ProcessInfo.processInfo.systemUptime <= deadline else { throw failure("Identity capture exceeded its 10-second budget") }
            guard viewport.width > 0, viewport.height > 32,
                  target.minX >= viewport.minX, target.maxX <= viewport.maxX else { throw failure("Identity has no safe readable viewport") }
            // Translation may change a CGRect subtraction by one representable floating-point step.
            let sameSize = abs(target.width - previousSize.width) <= max(target.width.ulp, previousSize.width.ulp)
                && abs(target.height - previousSize.height) <= max(target.height.ulp, previousSize.height.ulp)
            guard covered == 0 || sameSize else { throw failure("Identity geometry changed after an accepted segment for \(label): \(previousSize) -> \(target.size); current CGRect=\(target)") }
            if covered == 0 { previousSize = target.size }
            let from = max(0, viewport.minY - target.minY)
            let to = min(target.height, viewport.maxY - target.minY)
            let fits = viewport.contains(target)
            // A near-fitting field may use overlapping originals instead of chasing a narrow alignment window.
            let readablePrefix = from == 0 && to >= min(target.height, viewport.height / 2)
            if fits || covered > 0 || readablePrefix {
                guard from <= covered && to > covered else { throw failure("Readable identity segments must overlap without gaps") }
                part += 1
                let geometry = XCTAttachment(string: "label=\(label)\nfield=\(target)\nviewport=\(viewport)\ncovered=\(from)...\(to)/\(target.height)")
                geometry.name = "\(page)-Part\(part)-geometry"
                geometry.lifetime = .keepAlways
                add(geometry)
                capture("\(page)-Part\(part)")
                covered = to
                guard ProcessInfo.processInfo.systemUptime <= deadline else { throw failure("Identity capture exceeded its 10-second budget") }
                if covered >= target.height { return }
            }
            guard action < 8 else { throw failure("Identity was not fully captured within eight native drags") }
            let visibleCoverage = max(0, to - from)
            let limit = min(300, min(viewport.height / 2 - 8, covered > 0 ? visibleCoverage - 8 : viewport.height / 2 - 8))
            let desired: CGFloat
            if covered == 0 {
                // Correct only the missing edge; do not force an otherwise readable field to top + 8.
                desired = target.minY < viewport.minY ? viewport.minY - target.minY : viewport.maxY - min(target.height, viewport.height / 2) - target.minY
            } else {
                desired = -min(limit, target.height - covered + 8)
            }
            guard limit >= 12, desired != 0 else { throw failure("No safe effective native pan distance") }
            let distance = max(12, min(limit, abs(desired)))
            let shift = desired < 0 ? -distance : distance
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX - application.frame.minX, dy: viewport.midY - application.frame.minY))
            let end = start.withOffset(CGVector(dx: 0, dy: shift))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.2)
        }
    }

    @MainActor
    private func identity(_ element: XCUIElement, fields: [String]) throws {
        reveal(element)
        guard element.waitForExistence(timeout: 10) else { throw failure("Missing identity row") }
        let label = element.label
        var remainder = label.startIndex..<label.endIndex
        for field in fields {
            guard let range = label.range(of: field, range: remainder) else {
                throw failure("Identity field absent or out of order: \(field) in \(label)")
            }
            remainder = range.upperBound..<label.endIndex
        }
    }

    @discardableResult
    @MainActor
    private func text(_ label: String) throws -> XCUIElement {
        let element = app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
        reveal(element)
        guard element.waitForExistence(timeout: 10) else { throw failure("Missing text: \(label)") }
        XCTAssertTrue(element.isHittable)
        return element
    }

    @MainActor
    private func open(_ id: String) throws { try activate(app.buttons[id]) }

    @MainActor
    private func back() throws { try activate(app.navigationBars.buttons.element(boundBy: 0)) }

    @MainActor
    private func activate(_ element: XCUIElement) throws {
        reveal(element)
        guard element.waitForExistence(timeout: 10) else { throw failure("Missing native control") }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: element)
        guard XCTWaiter.wait(for: [ready], timeout: 10) == .completed else { throw failure("Control not actionable") }
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

    private func failure(_ message: String) -> NSError {
        XCTFail(message)
        return NSError(domain: "CatalogIdentityAcceptance", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func capture(_ page: String) {
        let prefix = "catalog-identity-\(language)-\(page)"
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = prefix
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = prefix + "-AX"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}

/// Same existing wire entities and IDs; only display text and supported nullable context vary.
/// This opt-in response transform never changes the default fixture or authorization/mutation handling.
enum CatalogIdentityAcceptanceFacts {
    static let courseCode = "MATH101-INTERDISCIPLINARY-MATHEMATICAL-MODELLING"
    static let sectionCode = "MATH101-INTERDISCIPLINARY-MATHEMATICAL-MODELLING.01"
    static let historicalCode = "MATH101-INTERDISCIPLINARY-MATHEMATICAL-MODELLING.OLD"
    static let courseEn = "Calculus and Interdisciplinary Mathematical Modelling"
    static let courseCn = "高等微积分与跨学科数学建模的理论方法和综合实践"
    static let teacherEn = "Ada Teacher — Mathematical Modelling and Scientific Computing"
    static let teacherCn = "艾达老师——数学建模与科学计算综合教学"

    static func displayedCode(_ code: String) -> String {
        switch code {
        case "MATH101": courseCode
        case "MATH101.01": sectionCode
        case "MATH101.OLD": historicalCode
        default: code
        }
    }

    static func matches(sectionCode: String?, courseCode: String?, query: String) -> Bool {
        [sectionCode, courseCode].compactMap { $0 }.contains {
            displayedCode($0).uppercased() == query.uppercased()
        }
    }

    static func response(_ value: Any) -> Any {
        if let rows = value as? [Any] { return rows.map(response) }
        guard var object = value as? [String: Any] else { return value }
        for (key, value) in object { object[key] = response(value) }
        if object["code"] as? String == "MATH101", object["jwId"] as? Int == 1001 {
            object["code"] = displayedCode("MATH101")
            object["nameEn"] = courseEn
            object["nameCn"] = courseCn
        }
        if object["jwId"] as? Int == 42, object["code"] as? String == "MATH101.01" {
            object["code"] = displayedCode("MATH101.01")
        }
        if object["id"] as? Int == 3, object["nameEn"] as? String == "Ada Teacher" {
            object["nameEn"] = teacherEn
            object["nameCn"] = teacherCn
        }
        if object["jwId"] as? Int == 44, object["code"] as? String == "MATH101.OLD" {
            object["code"] = displayedCode("MATH101.OLD")
            object["course"] = NSNull()
            object["teachers"] = [] as [Any]
            object["semester"] = NSNull()
        }
        return object
    }
}

import XCTest

/// Real shell controls only. Menu steps share the caller's existing entry budget.
@MainActor
enum PrimaryNavigation {
    private static let sidebarLabels = ["Show Sidebar", "Toggle Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    static func select(_ name: String, index: Int, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        guard dismissAccountIfNeeded(in: app, until: deadline) else { return }
        let tabs = app.tabBars.element
        if tabs.exists {
            let tab = tabs.buttons.element(boundBy: index)
            guard ready(tab, until: deadline) else { return }
            tab.tap()
        } else {
            let tab = app.buttons.matching(identifier: "Tab.\(name)").element
            guard showRailIfNeeded(for: tab, in: app, until: deadline, hasTabBar: false) else { return }
            guard ready(tab, until: deadline) else { return }
            tab.tap()
        }
    }

    static func openAccount(_ destination: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let menu = accountControl("account_menu", in: app)
        guard let available = observeAccountControl(menu, id: "account_menu", until: deadline) else { return }
        if !available {
            guard dismissAccountIfNeeded(in: app, until: deadline) else { return }
            guard showRailIfNeeded(for: menu, in: app, until: deadline) else { return }
            guard ready(menu, until: deadline, predicate: NSPredicate(format: "hittable == true")) else { return }
        }
        app.buttons.matching(identifier: "account_menu").element.tap()
        let id = "account_menu_\(destination)"
        let entry = accountControl(id, in: app)
        guard ready(entry, until: deadline, predicate: NSPredicate(format: "hittable == true")) else { return }
        app.buttons.matching(identifier: id).element.tap()
    }

    private static func dismissAccountIfNeeded(in app: XCUIApplication, until deadline: TimeInterval) -> Bool {
        let done = app.buttons.matching(identifier: "account_destination_done").element
        if done.exists {
            guard ready(done, until: deadline) else { return false }
            done.tap()
        }
        return true
    }

    private static func showRailIfNeeded(for element: XCUIElement, in app: XCUIApplication, until deadline: TimeInterval, hasTabBar: Bool? = nil) -> Bool {
        if !element.isHittable && !(hasTabBar ?? app.tabBars.element.exists) {
            let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).element
            guard ready(toggle, until: deadline) else { return false }
            toggle.tap()
        }
        return true
    }

    private static func accountControl(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: id)
            .matching(NSPredicate(format: "enabled == true")).element
    }

    private static func observeAccountControl(_ control: XCUIElement, id: String, until deadline: TimeInterval) -> Bool? {
        let predicate = NSPredicate(format: "hittable == true")
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            XCTFail("The account entry budget expired before observing \(id)")
            return nil
        }
        let available = predicate.evaluate(with: control)
        guard ProcessInfo.processInfo.systemUptime <= deadline else {
            XCTFail("The account entry budget expired while observing \(id)")
            return nil
        }
        return available
    }

    private static func ready(_ element: XCUIElement, until deadline: TimeInterval, predicate: NSPredicate? = nil) -> Bool {
        let predicate = predicate ?? NSPredicate(format: "exists == true AND enabled == true AND hittable == true")
        guard withinDeadline(deadline, after: "starting the control observation") else { return false }
        let available = predicate.evaluate(with: element)
        guard withinDeadline(deadline, after: "observing the control") else { return false }
        if available { return true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: max(0, deadline - ProcessInfo.processInfo.systemUptime))
        XCTAssertEqual(result, .completed, "The unique shell control should be available: \(element)")
        let inTime = withinDeadline(deadline, after: "waiting for the control")
        return result == .completed && inTime
    }

    private static func withinDeadline(_ deadline: TimeInterval, after action: String) -> Bool {
        let inTime = ProcessInfo.processInfo.systemUptime <= deadline
        XCTAssertTrue(inTime, "The original shell entry budget expired after \(action)")
        return inTime
    }
}

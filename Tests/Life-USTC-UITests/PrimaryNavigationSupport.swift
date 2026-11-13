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
            guard showRailIfNeeded(for: tab, in: app, until: deadline) else { return }
            guard ready(tab, until: deadline) else { return }
            tab.tap()
        }
    }

    static func openAccount(_ destination: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        guard dismissAccountIfNeeded(in: app, until: deadline) else { return }
        let menu = app.buttons.matching(identifier: "account_menu").element
        guard showRailIfNeeded(for: menu, in: app, until: deadline) else { return }
        guard readyAccountControl("account_menu", in: app, until: deadline) else { return }
        menu.tap()
        let entry = app.buttons.matching(identifier: "account_menu_\(destination)").element
        guard readyAccountControl("account_menu_\(destination)", in: app, until: deadline) else { return }
        entry.tap()
    }

    private static func dismissAccountIfNeeded(in app: XCUIApplication, until deadline: TimeInterval) -> Bool {
        let done = app.buttons.matching(identifier: "account_destination_done").element
        if done.exists {
            guard ready(done, until: deadline) else { return false }
            done.tap()
        }
        return true
    }

    private static func showRailIfNeeded(for element: XCUIElement, in app: XCUIApplication, until deadline: TimeInterval) -> Bool {
        if !app.tabBars.element.exists && !element.isHittable {
            let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).element
            guard ready(toggle, until: deadline) else { return false }
            toggle.tap()
        }
        return true
    }

    private static func readyAccountControl(_ id: String, in app: XCUIApplication, until deadline: TimeInterval) -> Bool {
        let control = app.buttons.matching(identifier: id)
            .matching(NSPredicate(format: "enabled == true")).element
        let predicate = NSPredicate(format: "hittable == true")
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            XCTFail("The account entry budget expired before observing \(id)")
            return false
        }
        let available = predicate.evaluate(with: control)
        guard ProcessInfo.processInfo.systemUptime <= deadline else {
            XCTFail("The account entry budget expired while observing \(id)")
            return false
        }
        if available { return true }
        let completed = ready(control, until: deadline, predicate: predicate)
        if completed && ProcessInfo.processInfo.systemUptime > deadline {
            XCTFail("The account entry budget expired while waiting for \(id)")
            return false
        }
        return completed
    }

    private static func ready(_ element: XCUIElement, until deadline: TimeInterval, predicate: NSPredicate? = nil) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate ?? NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: max(0, deadline - ProcessInfo.processInfo.systemUptime))
        XCTAssertEqual(result, .completed, "The unique shell control should be available: \(element)")
        return result == .completed
    }
}

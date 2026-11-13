import XCTest

/// Keep the original readiness timeout for each real shell control.
@MainActor
enum PrimaryNavigation {
    private static let sidebarLabels = ["Show Sidebar", "Toggle Sidebar", "Hide Sidebar", "Sidebar", "显示边栏", "隐藏边栏", "边栏"]

    static func select(_ name: String, index: Int, in app: XCUIApplication, timeout: TimeInterval = 10) {
        guard dismissAccountIfNeeded(in: app, timeout: timeout) else { return }
        let tabs = app.tabBars.element
        if tabs.exists {
            let tab = tabs.buttons.element(boundBy: index)
            guard ready(tab, timeout: timeout) else { return }
            tab.tap()
        } else {
            let tab = app.buttons.matching(identifier: "Tab.\(name)").element
            guard showRailIfNeeded(for: tab, in: app, timeout: timeout, hasTabBar: false) else { return }
            guard ready(tab, timeout: timeout) else { return }
            tab.tap()
        }
    }

    static func openAccount(_ destination: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let menu = accountControl("account_menu", in: app)
        let actionable = NSPredicate(format: "hittable == true")
        if !actionable.evaluate(with: menu) {
            guard dismissAccountIfNeeded(in: app, timeout: timeout) else { return }
            guard showRailIfNeeded(for: menu, in: app, timeout: timeout) else { return }
            guard ready(menu, timeout: timeout, predicate: actionable) else { return }
        }
        app.buttons.matching(identifier: "account_menu").element.tap()
        let id = "account_menu_\(destination)"
        let entry = accountControl(id, in: app)
        guard ready(entry, timeout: timeout, predicate: actionable) else { return }
        app.buttons.matching(identifier: id).element.tap()
    }

    private static func dismissAccountIfNeeded(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let done = app.buttons.matching(identifier: "account_destination_done").element
        if done.exists {
            guard ready(done, timeout: timeout) else { return false }
            done.tap()
        }
        return true
    }

    private static func showRailIfNeeded(for element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval, hasTabBar: Bool? = nil) -> Bool {
        if !element.isHittable && !(hasTabBar ?? app.tabBars.element.exists) {
            let toggle = app.buttons.matching(NSPredicate(format: "label IN %@", sidebarLabels)).element
            guard ready(toggle, timeout: timeout) else { return false }
            toggle.tap()
        }
        return true
    }

    private static func accountControl(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: id)
            .matching(NSPredicate(format: "enabled == true")).element
    }

    private static func ready(_ element: XCUIElement, timeout: TimeInterval, predicate: NSPredicate? = nil) -> Bool {
        let predicate = predicate ?? NSPredicate(format: "exists == true AND enabled == true AND hittable == true")
        if predicate.evaluate(with: element) { return true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "The unique shell control should be available: \(element)")
        return result == .completed
    }
}

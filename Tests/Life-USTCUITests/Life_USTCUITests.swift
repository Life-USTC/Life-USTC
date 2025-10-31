import XCTest

final class Life_USTCUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppHasWindow() throws {
        // Basic sanity test: the app's first window exists after launch
        XCTAssertTrue(app.windows.element(boundBy: 0).exists)
    }
}

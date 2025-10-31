import XCTest

final class Life_USTCUITestsLaunchTests: XCTestCase {
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}

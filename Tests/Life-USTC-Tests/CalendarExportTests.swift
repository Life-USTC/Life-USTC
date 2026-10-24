import XCTest
@testable import Life_USTC

final class CalendarExportTests: XCTestCase {
    private let base = URL(string: "https://calendar.example")!

    func testSingleSectionExportUsesJWIdentity() {
        XCTAssertEqual(ServerCalendarLinks.section(42001, baseURL: base).absoluteString,
                       "https://calendar.example/api/catalog/sections/42001/calendar.ics")
    }

    func testCombinedExportUsesSortedUniqueInternalIdentities() throws {
        let url = try XCTUnwrap(ServerCalendarLinks.sections([9, 3, 9], baseURL: base))
        XCTAssertEqual(url.path, "/api/catalog/sections/calendar.ics")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                       [.init(name: "sectionIds", value: "3,9")])
    }

    func testCombinedExportRequiresOneToFiftyPositiveUniqueSections() {
        XCTAssertNil(ServerCalendarLinks.sections([], baseURL: base))
        XCTAssertNil(ServerCalendarLinks.sections([0], baseURL: base))
        XCTAssertNil(ServerCalendarLinks.sections([-1], baseURL: base))
        XCTAssertNil(ServerCalendarLinks.sections(Array(1...51), baseURL: base))
        XCTAssertNotNil(ServerCalendarLinks.sections(Array(1...50), baseURL: base))
        XCTAssertNotNil(ServerCalendarLinks.sections(Array(repeating: 1, count: 51), baseURL: base))
    }
}

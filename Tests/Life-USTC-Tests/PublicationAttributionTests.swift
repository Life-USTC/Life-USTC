import XCTest
@testable import Life_USTC

final class PublicationAttributionTests: XCTestCase {
    func testDropsCrawlerPlaceholdersAndURLOnlyValues() {
        for value in ["", " \n ", "网站", "栏目", "首页", "未知", "NONE", "null", "undefined", "N/A",
                      "site", "Category", "unknown", "—", "–", "-", "...", "?! ★", "https://example.org/editor"] {
            XCTAssertNil(PublicationAttribution.value(value), value)
        }
        XCTAssertNil(PublicationAttribution.value(nil))
    }

    func testPreservesNamesAndMeaningfulLabelsAfterTrimming() {
        XCTAssertEqual(PublicationAttribution.value("  Campus Newsroom \n"), "Campus Newsroom")
        XCTAssertEqual(PublicationAttribution.value("李明、王芳"), "李明、王芳")
        XCTAssertEqual(PublicationAttribution.value("Dr. O'Connor"), "Dr. O'Connor")
        XCTAssertEqual(PublicationAttribution.value("新闻中心（编辑部）"), "新闻中心（编辑部）")
    }
}

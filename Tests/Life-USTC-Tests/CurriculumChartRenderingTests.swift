import SwiftUI
import XCTest
@testable import Life_USTC

final class CurriculumChartRenderingTests: XCTestCase {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-10-19T08:00:00+08:00")!

    @MainActor
    func testEmptyWeekRendersWithoutAppSchoolInitialization() throws {
        try assertRendersWithoutSelectedSchool(lectures: [])
    }

    @MainActor
    func testScheduledWeekRendersWithoutAppSchoolInitialization() throws {
        let lecture = Lecture(
            startDate: referenceDate,
            endDate: referenceDate.addingTimeInterval(90 * 60),
            name: "Calculus",
            location: "East 2201",
            startIndex: 1,
            endIndex: 2
        )
        try assertRendersWithoutSelectedSchool(lectures: [lecture])
    }

    @MainActor
    private func assertRendersWithoutSelectedSchool(lectures: [Lecture]) throws {
        let previousSchool: School? = SchoolSystem.current
        SchoolSystem.current = nil
        defer { SchoolSystem.current = previousSchool }

        let renderer = ImageRenderer(content: CurriculumChartView(
            lectures: lectures,
            referenceDate: referenceDate,
            behavior: .ustc
        ).frame(width: 720, height: 320))
        renderer.scale = 1

        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.width, 720)
        XCTAssertEqual(image.height, 320)
        XCTAssertNil(SchoolSystem.current)
    }
}

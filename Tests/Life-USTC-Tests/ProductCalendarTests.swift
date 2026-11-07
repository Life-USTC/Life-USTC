import Foundation
import XCTest
@testable import Life_USTC

final class ProductCalendarTests: XCTestCase {
    func testSundayBoundaryUsesShanghaiRegardlessOfDeviceDefaults() {
        let before = date("2026-08-29T15:59:59Z")
        let sunday = date("2026-08-29T16:00:00Z")
        XCTAssertEqual(ProductCalendar.calendar.firstWeekday, 1)
        XCTAssertEqual(ProductCalendar.calendar.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(before.startOfWeek(), date("2026-08-22T16:00:00Z"))
        XCTAssertEqual(sunday.startOfWeek(), sunday)
        XCTAssertEqual(ProductCalendar.weekRange(containing: sunday).upperBound, date("2026-09-05T16:00:00Z"))
    }

    func testWeekAndDayExcludeTheirNextBoundary() {
        let sunday = date("2026-08-29T16:00:00Z")
        let nextSunday = date("2026-09-05T16:00:00Z")
        let week = ProductCalendar.weekRange(containing: sunday)
        XCTAssertTrue(week.contains(sunday))
        XCTAssertTrue(week.contains(nextSunday.addingTimeInterval(-1)))
        XCTAssertFalse(week.contains(nextSunday))
        let day = ProductCalendar.dayRange(containing: sunday)
        XCTAssertTrue(day.contains(date("2026-08-30T15:59:59Z")))
        XCTAssertFalse(day.contains(date("2026-08-30T16:00:00Z")))
    }

    @MainActor
    func testCivilNavigationKeepsShanghaiSundayAcrossDeviceDSTTransitions() {
        let previousDefault = NSTimeZone.default
        let deviceZone = TimeZone(identifier: "America/Los_Angeles")!
        NSTimeZone.default = deviceZone
        defer { NSTimeZone.default = previousDefault }

        for (start, next) in [("2026-03-08", "2026-03-15"), ("2026-11-01", "2026-11-08")] {
            let sunday = civilDate(start)
            let nextSunday = civilDate(next)
            XCTAssertEqual(ProductCalendar.addingDays(7, to: sunday), nextSunday)
            XCTAssertEqual(ProductCalendar.addingDays(-7, to: nextSunday), sunday)
            XCTAssertEqual(ProductCalendar.addingDays(7, to: sunday).startOfWeek(), nextSunday)
        }
        XCTAssertEqual(ProductCalendar.addingDays(1, to: civilDate("2026-03-08")), civilDate("2026-03-09"))
        XCTAssertEqual(ProductCalendar.addingDays(2, to: civilDate("2026-03-08")), civilDate("2026-03-10"))

        // The prior device-calendar navigation lands on Saturday in Shanghai.
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = deviceZone
        let deviceAdvance = deviceCalendar.date(byAdding: .day, value: 7, to: civilDate("2026-03-08"))!
        XCTAssertEqual(deviceAdvance, date("2026-03-14T15:00:00Z"))
        XCTAssertNotEqual(deviceAdvance.startOfWeek(), civilDate("2026-03-15"))
    }

    func testOfficialAutumnAndSpringFirstWeeksBeginOnSunday() {
        for (start, end) in [("2026-08-30", "2027-01-15"), ("2026-03-01", "2026-07-10")] {
            let semesterStart = civilDate(start)
            XCTAssertEqual(ProductCalendar.teachingWeekNumber(
                containing: semesterStart, semesterStart: semesterStart, semesterEnd: civilDate(end)
            ), 1)
            XCTAssertEqual(ProductCalendar.weekRange(containing: semesterStart).lowerBound, semesterStart)
            XCTAssertEqual(ProductCalendar.teachingWeekNumber(
                containing: ProductCalendar.calendar.date(byAdding: .day, value: 7, to: semesterStart)!,
                semesterStart: semesterStart, semesterEnd: civilDate(end)
            ), 2)
        }
    }

    func testCalendarLabelsCoverFirstSundayAndLastDisplayRow() {
        let rawStart = civilDate("2026-08-31")
        let rawEnd = civilDate("2027-01-15")
        XCTAssertEqual(ProductCalendar.teachingWeekNumber(
            containing: civilDate("2026-08-30"), semesterStart: rawStart, semesterEnd: rawEnd
        ), 1)
        XCTAssertEqual(ProductCalendar.teachingWeekNumber(
            containing: civilDate("2027-01-16"), semesterStart: rawStart, semesterEnd: rawEnd
        ), 20)
        XCTAssertNil(ProductCalendar.teachingWeekNumber(
            containing: civilDate("2027-01-17"), semesterStart: rawStart, semesterEnd: rawEnd
        ))
        XCTAssertNil(ProductCalendar.teachingWeekNumber(
            containing: civilDate("2026-08-29"), semesterStart: rawStart, semesterEnd: rawEnd
        ))
    }

    func testUnknownOrInvalidSemesterDoesNotInventWeekNumber() {
        let day = civilDate("2026-08-30")
        XCTAssertNil(ProductCalendar.teachingWeekNumber(
            containing: day, semesterStart: .distantPast, semesterEnd: .distantFuture
        ))
        XCTAssertNil(ProductCalendar.teachingWeekNumber(
            containing: day, semesterStart: civilDate("2026-09-01"), semesterEnd: day
        ))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func civilDate(_ value: String) -> Date {
        date(value + "T00:00:00+08:00")
    }
}

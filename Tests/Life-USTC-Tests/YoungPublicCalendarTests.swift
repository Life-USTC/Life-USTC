import XCTest
@testable import Life_USTC

final class YoungPublicCalendarTests: XCTestCase {
    func testPublicWeekUsesSundayWhilePersonalWeekKeepsMonday() {
        let sunday = YoungCalendarDate.dateFormatter.date(from: "2026-10-25")!
        let publicWeek = YoungPublicCalendarDate.range(for: .week, date: sunday)
        XCTAssertEqual(YoungCalendarDate.dateString(publicWeek.start), "2026-10-25")
        XCTAssertEqual(YoungCalendarDate.dateString(publicWeek.end), "2026-10-31")
        XCTAssertEqual(publicWeek.days.count, 7)
        XCTAssertEqual(YoungCalendarDate.range(for: .week, date: sunday).from, "2026-10-19")
        XCTAssertEqual(YoungCalendarDate.range(for: .week, date: sunday).to, "2026-10-25")
    }

    func testMonthGridAlignsSundayAndCoversLeapFebruary() {
        let date = YoungCalendarDate.dateFormatter.date(from: "2028-02-16")!
        let days = YoungPublicCalendarDate.monthGrid(for: date).map(YoungCalendarDate.dateString)
        XCTAssertEqual(days.count, 35)
        XCTAssertEqual(days.first, "2028-01-30")
        XCTAssertEqual(days.last, "2028-03-04")
        XCTAssertTrue(days.contains("2028-02-29"))
        let range = YoungPublicCalendarDate.range(for: .month, date: date)
        XCTAssertEqual(YoungCalendarDate.dateString(range.start), "2028-02-01")
        XCTAssertEqual(YoungCalendarDate.dateString(range.end), "2028-02-29")
    }

    func testPublicDayUsesShanghaiMidnight() {
        let date = ISO8601DateFormatter().date(from: "2026-10-24T16:30:00Z")!
        let range = YoungPublicCalendarDate.range(for: .day, date: date)
        XCTAssertEqual(YoungCalendarDate.dateString(range.start), "2026-10-25")
        XCTAssertEqual(range.days.count, 1)
    }

    func testMonthAndWeekShowStartsWhileDayPlacesContinuingEventsLast() throws {
        let day = YoungCalendarDate.dateFormatter.date(from: "2026-10-25")!
        let events = try [event("ongoing", start: "2026-10-24T12:00:00+08:00", end: "2026-10-26T09:00:00+08:00"),
                          event("ended", start: "2026-10-24T12:00:00+08:00", end: "2026-10-25T00:00:00+08:00"),
                          event("b", start: "2026-10-25T09:00:00+08:00"),
                          event("a", start: "2026-10-25T09:00:00+08:00"),
                          event("unknown", start: nil, end: "2026-10-25T10:00:00+08:00")]
        for mode in [YoungCalendarDisplayMode.week, .month] {
            XCTAssertEqual(YoungFormatting.calendarEvents(events, on: day, mode: mode, basis: .activity).map(\.youngId), ["a", "b"])
        }
        XCTAssertEqual(YoungFormatting.calendarEvents(events, on: day, mode: .day, basis: .activity).map(\.youngId),
                       ["a", "b", "ongoing"])
    }

    func testRegistrationUsesItsOwnStartDay() throws {
        let day = YoungCalendarDate.dateFormatter.date(from: "2026-10-25")!
        let events = try [event("registration", start: "2026-10-28T09:00:00+08:00",
                                registration: "2026-10-25T08:00:00+08:00")]
        XCTAssertTrue(YoungFormatting.calendarEvents(events, on: day, mode: .week, basis: .activity).isEmpty)
        XCTAssertEqual(YoungFormatting.calendarEvents(events, on: day, mode: .week, basis: .registration).map(\.youngId),
                       ["registration"])
    }

    private func event(_ id: String, start: String?, end: String? = nil, registration: String? = nil) throws -> ServerYoungEvent {
        var object: [String: Any] = ["youngId": id, "name": id, "isActive": true,
                                    "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
                                    "signupDepartmentIds": [], "allowedAttachmentTypes": []]
        object["startAt"] = start
        object["endAt"] = end
        object["applyStartAt"] = registration
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ServerYoungEvent.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

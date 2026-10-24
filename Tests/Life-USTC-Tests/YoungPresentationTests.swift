import XCTest
@testable import Life_USTC

final class YoungPresentationTests: XCTestCase {
    func testOrganizerDigestLocalizesOnlyItsPrefixAndPreservesActivityNames() {
        let multiple = notification(kind: "organizer_digest", body: "2 个新活动 / new events: Quantum Lab, 中文活动")
        XCTAssertEqual(YoungFormatting.notificationDescription(multiple),
                       String(format: "%d new activities: ".localized, 2) + "Quantum Lab, 中文活动")
        let single = notification(kind: "organizer_digest", body: "1 个新活动 / new events: Quantum Lab")
        XCTAssertEqual(YoungFormatting.notificationDescription(single),
                       String(format: "%d new activity: ".localized, 1) + "Quantum Lab")
        let unchanged = notification(kind: "organizer_digest", body: "A future digest format")
        XCTAssertEqual(YoungFormatting.notificationDescription(unchanged), "A future digest format")
    }

    func testSourceUnavailableReminderStaysDistinctFromAnOrdinaryActivityChange() {
        let unavailable = notification(kind: "event_changed", body: "来源暂缺，请核实校方信息 / Source unavailable; check the official event page.")
        XCTAssertEqual(YoungFormatting.notificationDescription(unavailable),
                       "The source is currently unavailable. Check the official event page before attending or registering.".localized)
        let changed = notification(kind: "event_changed", body: "Activity updated")
        XCTAssertEqual(YoungFormatting.notificationDescription(changed),
                       "Activity details or source availability changed. Check the latest time, venue and registration status.".localized)
    }

    func testReminderTimingMatchesServerLeadTimes() {
        XCTAssertEqual(YoungFormatting.notificationDescription(notification(kind: "signup_deadline", body: "")),
                       "Registration closes within 24 hours. Check the deadline before signing up.".localized)
        XCTAssertEqual(YoungFormatting.notificationDescription(notification(kind: "event_start", body: "")),
                       "This activity starts within an hour. Check the time and venue.".localized)
    }

    func testUpstreamStatusTakesPrecedenceOverActiveFlag() throws {
        XCTAssertEqual(YoungFormatting.eventStatus(try event("active", status: "  Registration starts soon  ")),
                       "Registration starts soon")
        XCTAssertEqual(YoungFormatting.eventStatus(try event("closed", status: "Source registration paused", active: false)),
                       "Source registration paused")
    }

    func testAbsentOrBlankStatusUsesLocalizedOpenAndClosedFallbacks() throws {
        XCTAssertEqual(YoungFormatting.eventStatus(try event("active", status: " \n ")), "Open".localized)
        XCTAssertEqual(YoungFormatting.eventStatus(try event("closed", active: false)), "Closed".localized)
    }

    func testConflictsUseClassesExamsAndActivitiesButNotDeadlines() throws {
        let events = try [event("class", start: 30, end: 90), event("exam", start: 150, end: 210),
                          event("activity", start: 270, end: 330), event("todo", start: 390, end: 450),
                          event("homework", start: 510, end: 570)]
        let personal = try [occupied("schedule", start: 60, end: 120), occupied("exam", start: 180, end: 240),
                            occupied("young_event", start: 300, end: 360), occupied("todo", start: 420, end: 480),
                            occupied("homework", start: 540, end: 600)]
        XCTAssertEqual(YoungFormatting.calendarConflicts(events: events, personal: personal),
                       Set(["class", "exam", "activity"]))
    }

    func testConflictsUseHalfOpenIntervalsAndKnownStartPoints() throws {
        let events = try [event("before", start: 0, end: 60), event("inside", start: 90, end: 100),
                          event("after", start: 120, end: 180), event("point-at-start", start: 60, end: nil),
                          event("point-at-end", start: 120, end: nil), event("zero-length", start: 90, end: 90)]
        let personal = try [occupied("schedule", start: 60, end: 120)]
        XCTAssertEqual(YoungFormatting.calendarConflicts(events: events, personal: personal),
                       Set(["inside", "point-at-start", "zero-length"]))
    }

    func testUnknownOrReversedActivityDatesCannotEstablishConflicts() throws {
        let events = try [event("unknown", start: nil, end: 90), event("reversed", start: 100, end: 80)]
        let personal = try [occupied("schedule", start: 60, end: 120)]
        XCTAssertTrue(YoungFormatting.calendarConflicts(events: events, personal: personal).isEmpty)
    }

    func testUnknownZeroLengthAndReversedPersonalDatesAreNotOccupiedTime() throws {
        let events = try [event("candidate", start: 30, end: 120)]
        let personal = try [occupied("schedule", start: nil, end: 100), occupied("exam", start: 60, end: nil),
                            occupied("young_event", start: 90, end: 90), occupied("exam", start: 100, end: 80)]
        XCTAssertTrue(YoungFormatting.calendarConflicts(events: events, personal: personal).isEmpty)
    }

    func testSubscribedActivityDoesNotConflictWithItself() throws {
        let events = try [event("same", start: 60, end: 120), event("other", start: 90, end: 150)]
        let personal = try [occupied("young_event", start: 60, end: 120, youngId: "same")]
        XCTAssertEqual(YoungFormatting.calendarConflicts(events: events, personal: personal), Set(["other"]))
    }

    private func event(
        _ id: String, start: Int? = 60, end: Int? = 120, status: String? = nil, active: Bool = true
    ) throws -> ServerYoungEvent {
        var value: [String: Any] = ["youngId": id, "name": id, "isActive": active,
                                    "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
                                    "signupDepartmentIds": [], "allowedAttachmentTypes": []]
        value["startAt"] = start.map(timestamp)
        value["endAt"] = end.map(timestamp)
        value["status"] = status
        return try decode(value)
    }

    private func occupied(
        _ type: String, start: Int?, end: Int?, youngId: String? = nil
    ) throws -> ServerPersonalCalendarEvent {
        var value: [String: Any] = ["id": "\(type)-\(start ?? 0)", "type": type, "title": type, "url": "/workspace/calendar"]
        value["at"] = start.map(timestamp)
        value["endsAt"] = end.map(timestamp)
        value["youngId"] = youngId
        return try decode(value)
    }

    private func timestamp(_ minutes: Int) -> String {
        ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(minutes * 60)))
    }

    private func notification(kind: String, body: String) -> ServerYoungNotification {
        ServerYoungNotification(id: "notice", youngId: nil, organizerId: nil, kind: kind, title: "Reminder",
                                body: body, createdAt: .distantPast, readAt: nil, expiresAt: nil)
    }

    private func decode<T: Decodable>(_ object: [String: Any]) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

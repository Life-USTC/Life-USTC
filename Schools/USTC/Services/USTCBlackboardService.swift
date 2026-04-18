//
//  USTCBlackboardService.swift
//  Life@USTC
//
//  Typed service client for bb.ustc.edu.cn (Blackboard).
//  Requires an authenticated URLSession (cookies set by CAS+BB login).
//

import Foundation

private let logger = AppLogger.logger(for: "USTCBlackboard")

/// Provides typed access to bb.ustc.edu.cn APIs.
struct USTCBlackboardService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Calendar Events (Homework)

    /// Fetch homework/calendar events from Blackboard.
    func fetchCalendarEvents() async throws -> [BBCalendarEventDTO] {
        let url = URL(
            string: "https://www.bb.ustc.edu.cn/webapps/calendar/calendarData/selectedCalendarEvents?start=&end=&course_id=&mode=personal?start=&end=&course_id=&mode=personal"
        )!

        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let events = try decoder.decode([BBCalendarEventDTO].self, from: data)

        logger.debug("Fetched \(events.count) BB calendar events")
        return events
    }

    /// Parse a BB date string (ISO 8601 with milliseconds) into a Date.
    static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: raw)
    }
}

//
//  USTCBlackboardService.swift
//  Life@USTC
//
//  Typed service client for bb.ustc.edu.cn (Blackboard).
//  Requires an authenticated URLSession (cookies set by CAS+BB login).
//

import Foundation
import LifeClientCore

private let logger = AppLogger.logger(for: "USTCBlackboard")

/// Provides typed access to bb.ustc.edu.cn APIs.
struct USTCBlackboardService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func establishSession() async throws -> Bool {
        let (data, response) = try await session.data(from: USTCCAS.blackboardCASLoginURL)
        if let linkURL = try USTCCAS.blackboardLoginURL(from: data) {
            let (linkData, _) = try await session.data(from: linkURL)
            if let finalURL = try USTCCAS.blackboardFinalURL(from: linkData) {
                _ = try await session.data(from: finalURL)
            }
        }
        // The original login response remains the success signal after both optional hops.
        return response.url == USTCCAS.blackboardHomeURL
    }

    // MARK: - Calendar Events (Homework)

    /// Fetch homework/calendar events from Blackboard.
    func fetchCalendarEvents() async throws -> [USTCBlackboardSelectedCalendarEvent] {
        let (data, _) = try await session.data(from: USTCBlackboard.selectedCalendarEventsURL)
        let events = try USTCBlackboard.parseSelectedCalendarEvents(data)
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

//
//  Curriculum+SaveToCalendar.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import CoreLocation
import EventKit
import SwiftUI

/// Factory for creating calendar events from lectures with geographic location data
struct LectureLocationFactory {
    @ManagedData(.geoLocation) var geoLocation: [GeoLocationData]

    /// Creates calendar events from lectures, adding geographic coordinates when available
    /// - Parameters:
    ///   - lectures: Array of lectures to convert to events
    ///   - store: Event store to use for creating events
    /// - Returns: Array of calendar events with location data
    func makeEventWithLocation(
        from lectures: [Lecture],
        in store: EKEventStore = EKEventStore()
    ) async throws -> [EKEvent] {
        let locations: [GeoLocationData] = (try? await _geoLocation.retrive()) ?? []

        var result: [EKEvent] = []

        for lecture in lectures {
            let event = EKEvent(eventStore: store)
            event.title = lecture.name
            event.startDate = lecture.startDate
            event.endDate = lecture.endDate

            let locationName = lecture.location
            let location = locations.first {
                locationName.hasPrefix($0.name)
            }
            if let location {
                let ekLocation = EKStructuredLocation(title: locationName)
                ekLocation.geoLocation = CLLocation(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                event.structuredLocation = ekLocation
            } else {
                event.location = locationName
            }

            result.append(event)
        }

        return result
    }
}

extension Curriculum {
    /// Saves all curriculum lectures to the device calendar
    /// Creates a dedicated "Curriculum" calendar and adds all lectures as events with location data
    /// - Throws: Calendar access errors or event creation errors
    func saveToCalendar() async throws {
        let eventStore = EKEventStore()

        // Request calendar access
        if #available(iOS 17.0, *) {
            if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
                try await eventStore.requestFullAccessToEvents()
            }
        } else {
            if try await !eventStore.requestAccess(to: .event) {
                throw BaseError.runtimeError("Calendar access problem")
            }
        }

        let calendarName = "Curriculum".localized
        let calendars = eventStore.calendars(for: .event)
            .filter {
                $0.title == calendarName.localized
            }

        // Remove existing calendar with same name
        for calendar in calendars {
            try eventStore.removeCalendar(calendar, commit: true)
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = Color.accentColor.cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
        try eventStore.saveCalendar(calendar, commit: true)

        // Get all unique lectures and create events with location data
        let lectures = semesters.flatMap(\.courses).flatMap(\.lectures).union()
        let events = try await LectureLocationFactory().makeEventWithLocation(from: lectures, in: eventStore)

        // Save all events
        for event in events {
            event.calendar = calendar
            try eventStore.save(
                event,
                span: .thisEvent,
                commit: false
            )
        }
        try eventStore.commit()
    }
}

//
//  Exam+SaveToCalendar.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import EventKit
import SwiftUI

extension [Exam] {
    /// Saves all exams to the device calendar
    /// Creates a dedicated "Exam Arrangements" calendar and adds all exams as events
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

        let calendarName = "Exam Arrangements".localized
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

        // Add all exams as events
        for exam in self {
            let event = EKEvent(exam, in: eventStore)
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

extension EKEvent {
    /// Creates a calendar event from an Exam
    /// - Parameters:
    ///   - exam: The exam to convert to an event
    ///   - store: The event store to use
    convenience init(_ exam: Exam, in store: EKEventStore = EKEventStore()) {
        self.init(eventStore: store)
        title = exam.courseName + " " + exam.typeName
        location = exam.detailLocation
        notes = exam.description

        startDate = exam.startDate
        endDate = exam.endDate
    }
}

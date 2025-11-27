import CoreLocation
import EventKit
import SwiftData
import SwiftUI

struct CalendarSaveHelper {
    static let shared = CalendarSaveHelper()

    let calendarEventfactory: CalendarEventFactory = .shared
    private let saveLock = SaveLock()

    @Query var lectures: [Lecture]
    @Query var exams: [Exam]

    func saveCurriculum() async throws {
        let events = calendarEventfactory.fromLectures(lectures)
        try await saveEvents(
            events,
            calendarName: "Curriculum".localized
        )
    }

    func saveExams() async throws {
        let events = calendarEventfactory.fromExams(exams)
        try await saveEvents(
            events,
            calendarName: "Exams".localized
        )
    }

    private func saveEvents(
        _ events: [EKEvent],
        calendarName: String
    ) async throws {
        try await saveLock.withCriticalRegion {
            let eventStore = EKEventStore()

            if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
                try await eventStore.requestFullAccessToEvents()
            }

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
}

private actor SaveLock {
    func withCriticalRegion<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }
}

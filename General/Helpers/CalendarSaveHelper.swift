import CoreLocation
import EventKit
import SwiftData
import SwiftUI

enum CalendarSaveHelper {
    @MainActor
    static func saveCurriculum() async throws {
        let lectures = try SwiftDataStack.modelContext.fetch(FetchDescriptor<Lecture>())
        let events = try await CalendarEventFactory.fromLectures(lectures)
        try await saveEvents(
            events,
            calendarName: "Curriculum".localized
        )
    }

    @MainActor
    static func saveExams() async throws {
        let exams = try SwiftDataStack.modelContext.fetch(FetchDescriptor<Exam>())
        let events = try await CalendarEventFactory.fromExams(exams)
        try await saveEvents(
            events,
            calendarName: "Exams".localized
        )
    }

    private static func saveEvents(
        _ events: [EKEvent],
        calendarName: String
    ) async throws {
        try await calendarSaveLock.withCriticalRegion {
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

private let calendarSaveLock = SaveLock()

private actor SaveLock {
    func withCriticalRegion<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await operation()
    }
}

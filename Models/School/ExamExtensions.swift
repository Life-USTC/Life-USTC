//
//  ExamExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import EventKit
import SwiftUI

extension Exam {
    var isFinished: Bool {
        endDate <= Date()
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day],
                                        from: .now.stripTime(),
                                        to: startDate.stripTime()).day ?? 0
    }

    static func saveToCalendar(_ exams: [Exam]) async throws {
        let eventStore = EKEventStore()
        if try await !eventStore.requestAccess(to: .event) {
            throw BaseError.runtimeError("Calendar access problem")
        }
        let calendarName = "Upcoming Exams"
        var calendar: EKCalendar? = eventStore.calendars(for: .event).first(where: { $0.title == calendarName.localized })
        // try remove everything with that name in it
        if calendar != nil {
            try eventStore.removeCalendar(calendar!, commit: true)
        }

        calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar!.title = calendarName
        calendar!.cgColor = Color.accentColor.cgColor
        calendar!.source = eventStore.defaultCalendarForNewEvents?.source
        try! eventStore.saveCalendar(calendar!, commit: true)

        for exam in exams {
            let event = EKEvent(eventStore: eventStore)
            event.title = exam.courseName + " " + exam.typeName
            event.location = exam.classRoomName + "@" + exam.classRoomBuildingName
            event.notes = exam.description

            event.startDate = exam.startDate
            event.endDate = exam.endDate
            event.calendar = calendar
            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }

    /// Sort given exams by time(ascending), and put the ones that are already over to the end of the array
    static func show(_ exams: [Exam]) -> [Exam] {
        exams
            .filter { !$0.isFinished }
            .sorted { $0.startDate < $1.endDate }
            + exams
            .filter(\.isFinished)
            .sorted { $0.startDate > $1.endDate }
    }

    /// Merge two list of exam (addition only)
    static func merge(_ original: [Exam], with new: [Exam]) -> [Exam] {
        var result = original
        for exam in new {
            if !result.filter({ $0 == exam }).isEmpty {
                continue
            }
            result.append(exam)
        }
        return result
    }
}

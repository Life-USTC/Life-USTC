//
//  ExamExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import EventKit
import Foundation
import SwiftUI

extension Exam {
    var detailLocation: String {
        "\(classRoomDistrict) \(classRoomBuildingName) \(classRoomName)"
    }

    var isFinished: Bool { endDate <= Date() }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: .now, to: startDate).day
            ?? 0
    }
}

extension EKEvent {
    convenience init(_ exam: Exam, in store: EKEventStore = EKEventStore()) {
        self.init(eventStore: store)
        title = exam.courseName + " " + exam.typeName
        location = exam.classRoomName + "@" + exam.classRoomBuildingName
        notes = exam.description

        startDate = exam.startDate
        endDate = exam.endDate
    }
}

extension Exam {
    static func clean(_ exams: [Exam]) -> [Exam] {
        let hiddenExamName =
            ([String]
            .init(
                rawValue: UserDefaults.appGroup.string(forKey: "hiddenExamName")
                    ?? ""
            ) ?? [])
            .filter { !$0.isEmpty }
        let result = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) { return false }
            }
            return true
        }
        let hiddenResult = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) { return true }
            }
            return false
        }
        return Exam.show(result) + Exam.show(hiddenResult)
    }

    /// Sort given exams by time(ascending), and put the ones that are already over to the end of the array
    static func show(_ exams: [Exam]) -> [Exam] {
        exams.filter { !$0.isFinished }.sorted { $0.startDate < $1.endDate }
            + exams.filter(\.isFinished).sorted { $0.startDate > $1.endDate }
    }

    /// Merge two list of exam (addition only)
    static func merge(_ original: [Exam], with new: [Exam]) -> [Exam] {
        var result = original
        for exam in new {
            if !result.filter({ $0 == exam }).isEmpty { continue }
            result.append(exam)
        }
        return result
    }

    static func saveToCalendar(_ exams: [Exam]) async throws {
        let eventStore = EKEventStore()
        if try await !eventStore.requestAccess(to: .event) {
            throw BaseError.runtimeError("Calendar access problem")
        }

        let calendarName = "Upcoming Exams"
        var calendar: EKCalendar? = eventStore.calendars(for: .event)
            .first(where: { $0.title == calendarName.localized })

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
            try eventStore.save(
                EKEvent(exam, in: eventStore),
                span: .thisEvent,
                commit: false
            )
        }
        try eventStore.commit()
    }
}

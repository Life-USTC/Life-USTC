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
        location = exam.detailLocation
        notes = exam.description

        startDate = exam.startDate
        endDate = exam.endDate
    }
}

extension [Exam] {
    func clean() -> [Exam] {
        let hiddenExamName =
            ([String]
            .init(
                rawValue: UserDefaults.appGroup.string(forKey: "hiddenExamName")
                    ?? ""
            ) ?? [])
            .filter { !$0.isEmpty }
        let result = self.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) { return false }
            }
            return true
        }
        let hiddenResult = self.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) { return true }
            }
            return false
        }
        return result.sort() + hiddenResult.sort()
    }

    /// Sort given exams by time(ascending), and put the ones that are already over to the end of the array
    func sort() -> [Exam] {
        self
            .filter { !$0.isFinished }
            .sorted { $0.startDate < $1.endDate }
        + self
            .filter(\.isFinished)
            .sorted { $0.startDate > $1.endDate }
    }

    /// Merge two list of exam (addition only)
    func merge(with exams: [Exam]) -> [Exam] {
        var result = self
        for exam in exams {
            if !result.filter({ $0 == exam }).isEmpty { continue }
            result.append(exam)
        }
        return result
    }

    func saveToCalendar() async throws {
        let eventStore = EKEventStore()
        if #available(iOS 17.0, *) {
            if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
                try await eventStore.requestFullAccessToEvents()
            }
        } else {
            // Fallback on earlier versions
            if try await !eventStore.requestAccess(to: .event) {
                throw BaseError.runtimeError("Calendar access problem")
            }
        }

        let calendarName = "Exam Arrangements".localized
        let calendars = eventStore.calendars(for: .event)
            .filter {
                $0.title == calendarName.localized
            }

        // try remove everything with that name in it
        for calendar in calendars {
            try eventStore.removeCalendar(calendar, commit: true)
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = Color.accentColor.cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
        try eventStore.saveCalendar(calendar, commit: true)

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

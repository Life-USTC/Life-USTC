//
//  CurriculumExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import EventKit
import Foundation
import SwiftUI

struct CurriculumBehavior {
    var shownTimes: [Int] = []
    var highLightTimes: [Int] = []

    var convertTo: (Int) -> Int = { $0 }
    var convertFrom: (Int) -> Int = { $0 }
}

/// Usage: `class exampleDelegaet: CurriculumProtocolA & CurriculumProtocol`
protocol CurriculumProtocolA {
    func refreshSemesterList() async throws -> [String]
    func refreshSemester(id: String) async throws -> Semester
}

extension CurriculumProtocolA {
    /// Parrallel refresh the whole curriculum
    func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let semesterList = try await refreshSemesterList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in semesterList {
                group.addTask { try? await self.refreshSemester(id: id) }
            }

            for await child in group {
                if let child { result.semesters.append(child) }
            }
        }
        return result
    }
}

/// - Note: Useful when semester startDate is not provided in `refreshSemesterList`
class CurriculumProtocolB: ManagedRemoteUpdateProtocol<Curriculum> {
    /// Return more info than just id and name, like start date and end date, but have empty courses
    func refreshSemesterBase() async throws -> [Semester] {
        assert(true)
        return []
    }

    func refreshSemester(inComplete: Semester) async throws -> Semester {
        assert(true)
        return .example
    }

    /// Parrallel refresh the whole curriculum
    override func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let incompleteSemesters = try await refreshSemesterBase()
        await withTaskGroup(of: Semester?.self) { group in
            for semester in incompleteSemesters {
                group.addTask {
                    try? await self.refreshSemester(inComplete: semester)
                }
            }

            for await child in group {
                if let child { result.semesters.append(child) }
            }
        }

        // Remove semesters with no courses
        result.semesters = result.semesters.filter { !$0.courses.isEmpty }
            .sorted { $0.startDate > $1.startDate }

        return result
    }
}

extension Curriculum {
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

        let calendarName = "Curriculum".localized
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

        for lecture in semesters.flatMap(\.courses).flatMap(\.lectures) {
            let event = EKEvent(lecture, in: eventStore)
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

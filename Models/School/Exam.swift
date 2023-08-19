//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftUI

struct Exam: Codable, Equatable {
    // MARK: - Information about the course

    /// Code to indicate which exact lesson the student is tanking, like MATH1000.01
    /// - Description:
    /// Make sure this is indentical in Score & Course.
    var lessonCode: String
    var courseName: String

    // MARK: - Information about the exam

    /// - Important:
    /// Shown on UI, please set a length limit
    /// - Description:
    /// Some notations are localized, such as 期末考试 <=> Final, 期中考试 <=> Mid-term, 小测 <=> Quiz
    var typeName: String

    var startDate: Date
    var endDate: Date
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String

    static let example: Exam = .init(lessonCode: "MATH10001.01",
                                     courseName: "数学分析B1",
                                     typeName: "期末考试",
                                     startDate: Date(),
                                     endDate: Date() + DateComponents(hour: 1),
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")
}

extension Exam {
    var detailString: String {
        "\(startDate.description(with: .current)) - \(endDate.description(with: .current)) @ \(classRoomName)"
    }

    var isFinished: Bool {
        endDate <= Date()
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day],
                                        from: .now.stripTime(),
                                        to: startDate.stripTime()).day ?? 0
    }
}

extension Exam {
    static func clean(_ exams: [Exam]) -> [Exam] {
        let hiddenExamName = ([String].init(rawValue: UserDefaults.appGroup.string(forKey: "hiddenExamName") ?? "") ?? []).filter { !$0.isEmpty }
        let result = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return false
                }
            }
            return true
        }
        let hiddenResult = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return true
                }
            }
            return false
        }
        return Exam.show(result) + Exam.show(hiddenResult)
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

extension Exam {
    /// Convert to EKEvent
    func event(in store: EKEventStore = EKEventStore()) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = courseName + " " + typeName
        event.location = classRoomName + "@" + classRoomBuildingName
        event.notes = description

        event.startDate = startDate
        event.endDate = endDate
        return event
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
            try eventStore.save(exam.event(), span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
}

protocol ExamDelegateProtocol {
    func refresh() async throws -> [Exam]
}

extension ManagedDataSource {
    var exam: any ManagedDataProtocol {
        ManagedUserDefaults(key: "exam", refreshFunc: Exam.sharedDelegate.refresh)
    }
}

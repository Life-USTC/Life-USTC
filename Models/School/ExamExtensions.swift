//
//  ExamExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import EventKit
import SwiftUI

extension Exam {
    static let example: Exam = .init(lessonCode: "MATH10001.01",
                                     courseName: "数学分析B1",
                                     typeName: "期末考试",
                                     rawTime: "2023-06-28 14:30~16:30",
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")

    var time: Date {
        parse().time
    }

    var timeDescription: String {
        parse().description
    }

    var startTime: Date {
        parse().startTime
    }

    var endTime: Date {
        parse().endTime
    }

    var isFinished: Bool {
        endTime <= Date()
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Date().stripTime(), to: time).day ?? 0
    }

    /// Parse self.time to a tuple of (date, time, start time, end time)
    ///
    /// - Returns: (date, time, start time, end time)
    private func parse() -> (time: Date, description: String, startTime: Date, endTime: Date) {
        let dateString = String(rawTime.prefix(10))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let result = dateFormatter.date(from: dateString) else {
            return (Date(), "Error", Date(), Date())
        }
        let times = String(rawTime.suffix(11)).matches(of: try! Regex("[0-9]+")).map { Int($0.0)! }
        if times.count != 4 {
            return (Date(), "Error", Date(), Date())
        }
        let startTime = result.addingTimeInterval(TimeInterval(times[0] * 60 * 60 + times[1] * 60))
        let endTime = result.addingTimeInterval(TimeInterval(times[2] * 60 * 60 + times[3] * 60))
        return (result.stripTime(), String(rawTime.suffix(11)), startTime, endTime)
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

            event.startDate = exam.startTime
            event.endDate = exam.endTime
            event.calendar = calendar
            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }

    /// Sort given exams by time(ascending), and put the ones that are already over to the end of the array
    static func show(_ exams: [Exam]) -> [Exam] {
        exams
            .filter { !$0.isFinished }
            .sorted { $0.startTime < $1.startTime }
            + exams
            .filter(\.isFinished)
            .sorted { $0.startTime > $1.startTime }
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

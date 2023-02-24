//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftSoup
import SwiftUI
import WidgetKit

struct Exam: Codable, Identifiable {
    var id = UUID()
    var classIDString: String
    var typeName: String
    var className: String
    var rawTime: String
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String

    static let example: Exam = .init(classIDString: "MATH10001.01",
                                     typeName: "期末考试",
                                     className: "数学分析B1",
                                     rawTime: "2023-02-28 14:30~16:30",
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")

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

    static func saveToCalendar(_ exams: [Exam]) throws {
        let eventStore = EKEventStore()
        let semaphore = DispatchSemaphore(value: 0)
        var result: (granted: Bool, error: (any Error)?) = (true, nil)
        eventStore.requestAccess(to: .event) { granted, error in
            result.granted = granted
            result.error = error
            semaphore.signal()
        }
        semaphore.wait()
        if !result.granted || result.error != nil {
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
            event.title = exam.className + " " + exam.typeName
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
}

extension Exam {
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
}

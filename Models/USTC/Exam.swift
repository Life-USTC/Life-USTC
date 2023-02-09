//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftUI

struct Exam: Codable, Identifiable {
    var id = UUID()
    var classIDString: String
    var typeName: String
    var className: String
    var time: String
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String

    static let example: Exam = .init(classIDString: "MATH10001.01",
                                     typeName: "期末考试",
                                     className: "数学分析B1",
                                     time: "2023-02-28 14:30~16:30",
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")

    func parseTime() -> (time: Date, description: String, startTime: Date, endTime: Date) {
        let dateString = String(time.prefix(10))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let result = dateFormatter.date(from: dateString)!.stripTime()
        let times = String(time.suffix(11)).matches(of: try! Regex("[0-9]+")).map { Int($0.0)! }
        let startTime = result.addingTimeInterval(TimeInterval(times[0] * 60 * 60 + times[1] * 60))
        let endTime = result.addingTimeInterval(TimeInterval(times[2] * 60 * 60 + times[3] * 60))
        return (result.stripTime(), String(time.suffix(11)), startTime, endTime)
    }

    func daysLeft() -> Int {
        Calendar.current.dateComponents([.day], from: Date().stripTime(), to: parseTime().time).day ?? 0
    }
}

extension Exam {
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
        if calendar == nil {
            calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar!.title = calendarName
            calendar!.cgColor = Color.accentColor.cgColor
            calendar!.source = eventStore.defaultCalendarForNewEvents?.source
            try! eventStore.saveCalendar(calendar!, commit: true)
        }

        for exam in exams {
            let event = EKEvent(eventStore: eventStore)
            event.title = exam.className + " " + exam.typeName
            event.location = exam.classRoomName + "@" + exam.classRoomBuildingName
            event.notes = exam.description

            let parsed = exam.parseTime()
            event.startDate = parsed.startTime
            event.endDate = parsed.endTime
            event.calendar = calendar
            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
}

//
//  Course.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import SwiftUI
import SwiftyJSON

struct Course: Identifiable, Equatable {
    var id: UUID {
        UUID(name: "\(dayOfWeek):\(startTime)-\(endTime)[\(name)//\(classIDString)]@\(classPositionString);\(classTeacherName),\(weekString)", nameSpace: .oid)
    }

    var dayOfWeek: Int
    var startTime: Int
    var endTime: Int
    var name: String
    var classIDString: String
    var classPositionString: String
    var classTeacherName: String
    var weekString: String
}

class CurriculumDelegate: CacheAsyncDataDelegate {
    typealias D = [Course]
    var lastUpdate: Date?
    var timeInterval: Double?
    var cacheName: String = "UstcUgAASCurriculumCache"
    var timeCacheName: String = "UstcUgAASLastUpdatedCurriculum"

    var cache = JSON()

    func parseCache() async throws -> [Course] {
        var result: [Course] = []
        for (_, subJson): (String, JSON) in cache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!,
                             startTime: Int(subJson["startUnit"].stringValue)!,
                             endTime: Int(subJson["endUnit"].stringValue)!,
                             name: subJson["courseName"].stringValue,
                             classIDString: subJson["courseCode"].stringValue,
                             classPositionString: classPositionString,
                             classTeacherName: subJson["teachers"][0].stringValue,
                             weekString: subJson["weeksStr"].stringValue)

            result.append(tmp)
        }
        return Course.clean(result)
    }

    func forceUpdate() async throws {
        print("!!! Refresh UgAAS Curriculum")
        try await UstcUgAASClient.main.login()
        let (_, response) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(UstcUgAASClient.main.getSemesterID())/print-data/\(tableID)?weekIndex=")!)
        cache = try JSON(data: data)
        lastUpdate = Date()
        try saveCache()
    }

    func saveToCalendar() async throws {
        Task {
            let courses = try await self.retrive()
            try Course.saveToCalendar(courses,
                                      name: UstcUgAASClient.main.semesterName,
                                      startDate: UstcUgAASClient.main.semesterStartDate)
        }
    }

    init() {
        exceptionCall {
            try self.loadCache()
        }
    }
}

/// Parse given weekStr, for example: "1-18", "1-7, 9-16" to EKRecurrenceRule List, just no any ideas on how to achieve that goal.
func parseWeekStr(_: String) -> [EKRecurrenceRule] {
    []
}

extension Course {
    static func saveToCalendar(_ courses: [Course], name: String, startDate: Date) throws {
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

        var calendar: EKCalendar? = eventStore.calendars(for: .event).first(where: { $0.title == name })
        // try remove everything with that name in it
        if calendar == nil {
            calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar!.title = name
            calendar!.cgColor = Color.accentColor.cgColor
            calendar!.source = eventStore.defaultCalendarForNewEvents?.source
            try! eventStore.saveCalendar(calendar!, commit: true)
        }

        for course in courses {
            let event = EKEvent(eventStore: eventStore)
            event.title = course.name
            event.location = course.classPositionString
            event.notes = "\(course.classIDString)@\(course.classTeacherName)"
            event.startDate = startDate.stripTime() + .init(day: course.dayOfWeek) + Course.startTimes[course.startTime - 1]
            event.endDate = startDate.stripTime() + .init(day: course.dayOfWeek) + Course.endTimes[course.endTime - 1]
            let rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: .init(occurrenceCount: 18))
            event.addRecurrenceRule(rule)
            event.calendar = calendar
            try eventStore.save(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }

    static func clean(_ courses: [Course]) -> [Course] {
        var cleanCourses = courses
        doubleForEach(courses) { course, secondCourse in
            if course.dayOfWeek == secondCourse.dayOfWeek {
                if course.classIDString == secondCourse.classIDString {
                    if course.startTime == secondCourse.endTime + 1 {
                        cleanCourses.removeAll(where: { $0 == course })
                        cleanCourses.removeAll(where: { $0 == secondCourse })
                        cleanCourses.append(Course(dayOfWeek: course.dayOfWeek,
                                                   startTime: secondCourse.startTime,
                                                   endTime: course.endTime,
                                                   name: course.name,
                                                   classIDString: course.classIDString,
                                                   classPositionString: course.classPositionString,
                                                   classTeacherName: course.classTeacherName,
                                                   weekString: course.weekString))
                    }
                    if secondCourse.startTime == course.endTime + 1 {
                        cleanCourses.removeAll(where: { $0 == course })
                        cleanCourses.removeAll(where: { $0 == secondCourse })
                        cleanCourses.append(Course(dayOfWeek: course.dayOfWeek,
                                                   startTime: course.startTime,
                                                   endTime: secondCourse.endTime,
                                                   name: course.name,
                                                   classIDString: course.classIDString,
                                                   classPositionString: course.classPositionString,
                                                   classTeacherName: course.classTeacherName,
                                                   weekString: course.weekString))
                    }
                }
                if course.startTime == secondCourse.startTime, course.endTime == secondCourse.endTime {
                    cleanCourses.removeAll(where: { $0 == course })
                    cleanCourses.removeAll(where: { $0 == secondCourse })
                    cleanCourses.append(Course(dayOfWeek: course.dayOfWeek,
                                               startTime: course.startTime,
                                               endTime: course.endTime,
                                               name: combine(course.name, secondCourse.name),
                                               classIDString: combine(course.classIDString, secondCourse.classIDString),
                                               classPositionString: combine(course.classPositionString, secondCourse.classPositionString),
                                               classTeacherName: combine(course.classTeacherName, secondCourse.classTeacherName),
                                               weekString: combine(course.weekString, secondCourse.weekString)))
                }
            }
        }
        return cleanCourses
    }

    static let startTimes: [DateComponents] =
        [.init(hour: 7, minute: 50),
         .init(hour: 8, minute: 40),
         .init(hour: 9, minute: 45),
         .init(hour: 10, minute: 35),
         .init(hour: 11, minute: 25),
         .init(hour: 14, minute: 0),
         .init(hour: 14, minute: 50),
         .init(hour: 15, minute: 55),
         .init(hour: 16, minute: 45),
         .init(hour: 17, minute: 35),
         .init(hour: 19, minute: 30),
         .init(hour: 20, minute: 20),
         .init(hour: 21, minute: 10)]

    static let endTimes: [DateComponents] =
        [.init(hour: 8, minute: 35),
         .init(hour: 9, minute: 25),
         .init(hour: 10, minute: 30),
         .init(hour: 11, minute: 20),
         .init(hour: 12, minute: 10),
         .init(hour: 14, minute: 45),
         .init(hour: 15, minute: 35),
         .init(hour: 16, minute: 40),
         .init(hour: 17, minute: 30),
         .init(hour: 18, minute: 20),
         .init(hour: 20, minute: 15),
         .init(hour: 21, minute: 5),
         .init(hour: 21, minute: 55)]
}

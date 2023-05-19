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

    /// 1-7 as Monday to Sunday
    var dayOfWeek: Int

    /*
     These two properties are required to show the course "un-related" to exactly time it starts and ends
     For example, a course starts at 7:00 and ends at 8:45
     but the user remebmers it as "the first course on Monday" and often refers to it as 1-2, not the exact time it starts and ends
     So we need to store the "1-2" part, and then show user the exact time it starts and ends (and for storing in calendar)
     However not all courses are like this, some courses don't have a fixed time, so we need to store the exact time it starts and ends, as (hour, minute)
     Then these two properties are then rounded from the nearest time in Course.startTimes and Course.endTimes
     */

    /// 1-13, matching to Course.startTimes
    fileprivate var startTime: Int
    /// 1-13, matching to Course.endTimes
    fileprivate var endTime: Int

    var name: String
    var classIDString: String
    var classPositionString: String
    var classTeacherName: String

    /// 1-4,6,8-9,10-15
    var weekString: String
    static let example: Course = .init(dayOfWeek: currentWeekDay,
                                       startTime: 1,
                                       endTime: 10,
                                       name: "操作系统原理与设计(H)",
                                       classIDString: "011705",
                                       classPositionString: "3A407",
                                       classTeacherName: "刑凯",
                                       weekString: "1-15")

    init(dayOfWeek: Int,
         startTime: Int,
         endTime: Int,
         name: String,
         classIDString: String,
         classPositionString: String,
         classTeacherName: String,
         weekString: String)
    {
        assert(startTime <= endTime, "startTime should be less than or equal to endTime")
        assert(Bool(1 ... 7 ~= dayOfWeek), "dayOfWeek should be in range 1-7")
        assert(Bool(1 ... 13 ~= startTime), "startTime should be in range 1-13")
        assert(Bool(1 ... 13 ~= endTime), "endTime should be in range 1-13")
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.name = name
        self.classIDString = classIDString
        self.classPositionString = classPositionString
        self.classTeacherName = classTeacherName
        self.weekString = weekString
    }
}

/// 1-4,6,8-9,10-15 -> [(1,4),(6,6),(8,9),(10,15)]
func parseWeekStr(_ weekString: String) -> [(start: Int, end: Int)] {
    // strip all spaces and split by ","
    let weekStrs = weekString.replacingOccurrences(of: " ", with: "").split(separator: ",")

    var weekRanges: [(start: Int, end: Int)] = []
    for weekStr in weekStrs {
        // split by "-"
        let weekStrRange = weekStr.split(separator: "-")
        if weekStrRange.count == 1 {
            // only one number
            let week = Int(weekStrRange[0]) ?? 1
            weekRanges.append((week, week))
        } else if weekStrRange.count == 2 {
            // two numbers
            let start = Int(weekStrRange[0]) ?? 1
            let end = Int(weekStrRange[1]) ?? 2
            weekRanges.append((start, end))
        } else {
            // invalid
            fatalError("Invalid week string: \(weekString)")
        }
    }

    return weekRanges
}

extension Course {
    var _startTime: DateComponents {
        Course.startTimes[startTime - 1]
    }

    var _endTime: DateComponents {
        Course.endTimes[endTime - 1]
    }

    var clockTime: String {
        _startTime.clockTime + " - " + _endTime.clockTime
    }

    static func filter(_ courses: [Course], week: Int, weekday: Int? = weekday()) -> [Course] {
        let course_filtered = courses.filter { course in
            let weekRanges = parseWeekStr(course.weekString)
            for weekRange in weekRanges {
                if let weekday {
                    if weekRange.start <= week, week <= weekRange.end, course.dayOfWeek == weekday {
                        return true
                    }
                } else {
                    if weekRange.start <= week, week <= weekRange.end {
                        return true
                    }
                }
            }
            return false
        }
        return course_filtered.sorted(by: { $0.startTime < $1.startTime })
    }

    static func filter(_ courses: [Course], week: Int, for date: Date) -> [Course] {
        filter(courses, week: week, weekday: weekday(for: date))
    }

    static func nextCoursse(_ courses: [Course], week: Int, now: Date = Date()) -> Course? {
        let course_filtered = filter(courses, week: week, weekday: weekday(for: now))
        let course_sorted = course_filtered.sorted { $0.startTime < $1.startTime }
        for course in course_sorted {
            if now.stripTime() + course._startTime > now {
                return course
            }
        }
        return nil
    }

    func isFinished(at: Date) -> Bool {
        Date().stripTime() + _endTime < at
    }

    var offset: Int {
        startTime - 1
    }

    var length: Int {
        endTime - startTime + 1
    }

    var timeDescription: String {
        "\(startTime) (\(_startTime.clockTime))-\(endTime) (\(_endTime.clockTime))"
    }

    static func saveToCalendar(_ courses: [Course], name: String, startDate: Date) async throws {
        // supporting week string
        let eventStore = EKEventStore()
        if try await !eventStore.requestAccess(to: .event) {
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
            event.calendar = calendar

            for weekRange in parseWeekStr(course.weekString) {
                event.startDate = startDate.stripTime() + .init(day: course.dayOfWeek) + Course.startTimes[course.startTime - 1] + .init(day: (weekRange.start - 1) * 7)
                event.endDate = startDate.stripTime() + .init(day: course.dayOfWeek) + Course.endTimes[course.endTime - 1] + .init(day: (weekRange.end - 1) * 7)
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }

        try eventStore.commit()
    }

    /// Clean the courses, combine the courses with same info and are adjacent.
    /// merge the courses with same dayOfWeek and startTime/endTime.
    /// - Deprecated: try load [Course] in better way, this way we couldn't distinguish the courses with same info but different weekString.
    @available(*, deprecated)
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

    fileprivate static let _startTimes = [[7, 50], [8, 40], [9, 45], [10, 35], [11, 25], [14, 0], [14, 50], [15, 55], [16, 45], [17, 35], [19, 30], [20, 20], [21, 10]]
    fileprivate static let _endTimes = [[8, 35], [9, 25], [10, 30], [11, 20], [12, 10], [14, 45], [15, 35], [16, 40], [17, 30], [18, 20], [20, 15], [21, 5], [21, 55]]

    static let startTimes: [DateComponents] = _startTimes.map { .init(hour: $0[0], minute: $0[1]) }
    static let endTimes: [DateComponents] = _endTimes.map { .init(hour: $0[0], minute: $0[1]) }
}

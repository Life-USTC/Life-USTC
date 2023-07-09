//
//  CourseExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import EventKit
import SwiftUI

extension Course {
    static let example: Course = .init(dayOfWeek: weekday(),
                                       startTime: 1,
                                       endTime: 10,
                                       startHHMM: "07:50",
                                       endHHMM: "21:55",
                                       name: "操作系统原理与设计(H)",
                                       lessonCode: "011705",
                                       roomName: "3A407",
                                       buildingName: "第三教学楼",
                                       teacherName: "刑凯",
                                       weekString: "1-100")

    var _startTime: DateComponents {
        startHHMM.hhmmToDateComponents
    }

    var _endTime: DateComponents {
        endHHMM.hhmmToDateComponents
    }

    var clockTime: String {
        startHHMM + "/" + endHHMM
    }

    var timeDescription: String {
        "\(startTime) [\(startHHMM)] -> \(endTime) [\(endHHMM)]"
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
}

/// "1-4,6,8-9,10-15" -> [1,2,3,4,6,8,9,10,11,12,13,14,15]
func parseWeek(with weekString: String) -> [Int] {
    let weekStrs = weekString.replacingOccurrences(of: " ", with: "").split(separator: ",")
    var weeks: [Int] = []
    for weekStr in weekStrs {
        let weekStrRange = weekStr.split(separator: "-")
        if weekStrRange.count == 1 {
            let week = Int(weekStrRange[0]) ?? 1
            weeks.append(week)
        } else if weekStrRange.count == 2 {
            let start = Int(weekStrRange[0]) ?? 1
            if let end = Int(weekStrRange[1]) {
                for week in start ... end {
                    weeks.append(week)
                }
            } else {
                // notice that in some case the representation of week is like "1-16单"
                // so we need to remove the "单" or "双" part
                let end = Int(weekStrRange[1].dropLast()) ?? 2
                if weekStrRange[1].hasSuffix("单") {
                    for week in start ... end where week % 2 == 1 {
                        weeks.append(week)
                    }
                } else if weekStrRange[1].hasSuffix("双") {
                    for week in start ... end where week % 2 == 0 {
                        weeks.append(week)
                    }
                } else {
                    fatalError("Invalid week string: \(weekString)")
                }
            }
        } else {
            fatalError("Invalid week string: \(weekString)")
        }
    }
    return weeks
}

extension Curriculum {
    func weekNumber(for date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: semesterStartDate, to: date)
        return components.day! / 7 + 1
    }

    func getCourses(week: Int, weekday: Int?) -> [Course] {
        courses.filter { course in
            if let weekday {
                return parseWeek(with: course.weekString).contains(week) && course.dayOfWeek == weekday
            } else {
                return parseWeek(with: course.weekString).contains(week)
            }
        }.sorted(by: {
            $0.startTime < $1.startTime
        })
    }

    func getCourses(for date: Date = Date()) -> [Course] {
        getCourses(week: weekNumber(for: date), weekday: weekday(for: date))
    }

    func nextCoursse(after date: Date = Date()) -> Course? {
        getCourses(for: date)
            .filter { !$0.isFinished(at: date) }
            .first
    }

    var todaysCourse: [Course] {
        getCourses()
    }
}

extension CurriculumDelegateProtocol {
    func saveToCalendar() async throws {
        let curriclum = try await retrive()
        let eventStore = EKEventStore()
        if try await !eventStore.requestAccess(to: .event) {
            throw BaseError.runtimeError("Calendar access problem")
        }

        var calendar: EKCalendar? = eventStore.calendars(for: .event).first(where: { $0.title == curriclum.semesterName })
        if calendar != nil {
            try eventStore.removeCalendar(calendar!, commit: true)
        }

        calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar!.title = curriclum.semesterName
        calendar!.cgColor = Color.accentColor.cgColor
        calendar!.source = eventStore.defaultCalendarForNewEvents?.source
        try! eventStore.saveCalendar(calendar!, commit: true)

        for course in curriclum.courses {
            for week in parseWeek(with: course.weekString) {
                let event = EKEvent(eventStore: eventStore)
                event.title = course.name
                event.location = course.roomName
                event.notes = "\(course.lessonCode)@\(course.teacherName)"
                event.calendar = calendar
                event.startDate = curriclum.semesterStartDate + .init(day: course.dayOfWeek + (week - 1) * 7) + course._startTime
                event.endDate = curriclum.semesterStartDate + .init(day: course.dayOfWeek + (week - 1) * 7) + course._endTime
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }

        try eventStore.commit()
    }
}

private extension String {
    var hhmmToInt: Int {
        let components = components(separatedBy: ":")
        let hour = Int(components[0]) ?? 0
        let minute = Int(components[1]) ?? 0
        return hour * 60 + minute
    }

    var hhmmToDateComponents: DateComponents {
        let components = components(separatedBy: ":")
        let hour = Int(components[0]) ?? 0
        let minute = Int(components[1]) ?? 0
        return .init(hour: hour, minute: minute)
    }
}

extension TimeListBasedCDP {
    func parseHHMMToInt(time: String, type: TimeMarkUpForCourse) -> Int {
        switch type {
        case .startTime:
            if let index = startTimes.firstIndex(of: time) {
                return index
            }

            let absOffsetList = startTimes.map { abs($0.hhmmToInt - time.hhmmToInt) }
            let minOffset = absOffsetList.min() ?? 0
            return absOffsetList.firstIndex(of: minOffset) ?? 0
        case .endTime:
            if let index = endTimes.firstIndex(of: time) {
                return index
            }

            let absOffsetList = endTimes.map { abs($0.hhmmToInt - time.hhmmToInt) }
            let minOffset = absOffsetList.min() ?? 0
            return absOffsetList.firstIndex(of: minOffset) ?? 0
        }
    }
}

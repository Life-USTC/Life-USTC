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
    var id: String {
        lessonCode + startHHMM + endHHMM + weekString + String(dayOfWeek)
    }

    /// 1-7 as Monday to Sunday
    var dayOfWeek: Int

    /// - Description:
    /// These two properties are required to show the course "un-related" to exactly time it starts and ends
    /// For example, a course starts at 7:00 and ends at 8:45
    /// but the user remebmers it as "the first course on Monday" and often refers to it as 1-2, not the exact time it starts and ends
    /// So we need to store the "1-2" part, and then show user the exact time it starts and ends (and for storing in calendar)
    /// However not all courses are like this, some courses don't have a fixed time,
    /// so we need to store the exact time it starts and ends, as in startHHMM, and endHHMM
    ///
    /// - Important:
    /// You must provide these two properties for the UI to show properly
    /// (Hint): You could rounded from the nearest time in startTimes and endTimes
    var startTime: Int
    var endTime: Int

    /// These two variables store the source of truth of time
    var startHHMM: String
    var endHHMM: String

    var name: String
    var lessonCode: String
    var roomName: String
    var buildingName: String
    var teacherName: String

    /// 1-4,6,8-9,10-15
    var weekString: String

    init(dayOfWeek: Int,
         startTime: Int,
         endTime: Int,
         startHHMM: String,
         endHHMM: String,
         name: String,
         lessonCode: String,
         roomName: String,
         buildingName: String,
         teacherName: String,
         weekString: String)
    {
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.startHHMM = startHHMM
        self.endHHMM = endHHMM
        self.name = name
        self.lessonCode = lessonCode
        self.roomName = roomName
        self.buildingName = buildingName
        self.teacherName = teacherName
        self.weekString = weekString

        // testing:
        assert(startTime <= endTime, "startTime should be less than or equal to endTime")
        assert(Bool(1 ... 7 ~= dayOfWeek), "dayOfWeek should be in range 1-7")
        assert(Bool(1 ... 13 ~= startTime), "startTime should be in range 1-13")
        assert(Bool(1 ... 13 ~= endTime), "endTime should be in range 1-13")
        // production:
        if startTime > endTime {
            self.startTime = 1
            self.endTime = 1
        }
        if !(1 ... 7 ~= dayOfWeek) {
            self.dayOfWeek = 1
        }
        if !(1 ... 13 ~= startTime) {
            self.startTime = 1
        }
        if !(1 ... 13 ~= endTime) {
            self.endTime = 1
        }
    }
}

struct Curriculum: Identifiable, Equatable {
    var id: Int {
        semesterID
    }

    var semesterID: Int
    var courses: [Course]
    var semesterName: String
    var semesterStartDate: Date
    var semesterEndDate: Date
    var semesterWeeks: Int

    static let example: Curriculum = .init(semesterID: 241,
                                           courses: [.example],
                                           semesterName: "2021秋季学期",
                                           semesterStartDate: Date(),
                                           semesterEndDate: Date(),
                                           semesterWeeks: 20)

    init(semesterID: Int = 0,
         courses: [Course] = [],
         semesterName: String = "",
         semesterStartDate: Date = Date(),
         semesterEndDate: Date = Date(),
         semesterWeeks: Int = 0)
    {
        self.semesterID = semesterID
        self.courses = courses
        self.semesterName = semesterName
        self.semesterStartDate = semesterStartDate
        self.semesterEndDate = semesterEndDate
        self.semesterWeeks = semesterWeeks
    }
}

enum TimeMarkUpForCourse {
    case startTime
    case endTime
}

protocol CurriculumDelegateProtocol: ObservableObject, UserDefaultsADD & LastUpdateADD & NotifyUserWhenUpdateADD where D.Type == Curriculum.Type {
    /// After which time the course is considered to be ended (including that time)
    /// So `startTimes[lunchbreakTime]` is when the first course after lunch break starts
    /// `0..<lunchbreakTime` is morning, `lunchbreakTime..<endTimes.count` is afternoon
    var lunchbreakTime: Int { get }
    var dinnerbreakTime: Int { get }

    /// Given a time, return the index of the nearest time in startTimes
    func parseHHMMToInt(time: String, type: TimeMarkUpForCourse) -> Int
    func saveToCalendar() async throws
}

extension CurriculumDelegateProtocol {
    var nameToShowWhenUpdate: String {
        "Curriculum"
    }
}

protocol TimeListBasedCDP: CurriculumDelegateProtocol {
    var startTimes: [String] { get }
    var endTimes: [String] { get }
}

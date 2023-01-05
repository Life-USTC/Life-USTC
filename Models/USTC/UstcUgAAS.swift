//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import EventKit
import Foundation
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

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    static var main = UstcUgAASClient()
    static let semesterIDList: [String: String] = ["2021年秋季学期": "221", "2022年春季学期": "241", "2022年夏季学期": "261", "2022年秋季学期": "281", "2023年春季学期": "301"]

    var jsonCache = JSON() // save&load as /document/ugaas_cache.json
    var semesterID: String = "301"
    var lastLogined: Date?
    var courses: [Course] = []

    /// Load /Document/ugaas_cache.json to self.jsonCache
    func loadCache() throws {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "UstcUgAASLastLogined") {
            lastLogined = try decoder.decode(Date.self, from: data)
        }

        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = path + "/ugaas_cache.json"
        if fileManager.fileExists(atPath: filePath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            jsonCache = try JSON(data: data)
        } else {
            Task {
                try await forceUpdate()
            }
        }
    }

    /// Save /Document/ugaas_cache.json to self.jsonCache
    func saveCache() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(lastLogined)
        UserDefaults.standard.set(data, forKey: "UstcUgAASLastLogined")

        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = path + "/ugaas_cache.json"
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(atPath: filePath)
        }
        try jsonCache.rawData().write(to: URL(fileURLWithPath: filePath))
    }

    func login() async throws {
        if try await !UstcCasClient.main.checkLogined() {
            if try await !UstcCasClient.main.loginToCAS() {
//                throw URLError()
                return
            }
        }

        let session = URLSession.shared
        // jw.ustc.edu.cn login.
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())
        let _ = try await session.data(for: request)
    }

    func getCurriculum() async throws -> [Course] {
        if lastLogined == nil {
            try await forceUpdate()
        }
        var result: [Course] = []
        for (_, subJson): (String, JSON) in jsonCache["studentTableVm"]["activities"] {
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
        courses = Course.clean(result)
        return courses
    }

    func forceUpdate() async throws {
        try await login()
        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)
        let (_, response) = try await session.data(for: request)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        let (data, _) = try await session.data(for: URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(semesterID)/print-data/\(tableID)?weekIndex=")!))
        jsonCache = try JSON(data: data)
        lastLogined = Date()
        try saveCache()
    }

    func saveToCalendar() {
        var store = EKEventStore()
        store.requestAccess(to: .event) { _, _ in
        }
        for course in courses {}
    }

    init() {
        exceptionCall(loadCache)
    }
}

func combine(_ lhs: String, _ rhs: String) -> String {
    if lhs == rhs {
        return lhs
    } else {
        return "\(lhs) & \(rhs)"
    }
}

extension ContentView {
    func loadMainUstcUgAASClient() throws {
        UstcUgAASClient.main.semesterID = semesterID
    }
}

extension Course {
    static func clean(_ courses: [Course]) -> [Course] {
        var cleaneCourse = courses
        doubleForEach(courses) { course, secondCourse in
            if course.dayOfWeek == secondCourse.dayOfWeek {
                if course.classIDString == secondCourse.classIDString {
                    if course.startTime == secondCourse.endTime + 1 {
                        cleaneCourse.removeAll(where: { $0 == course })
                        cleaneCourse.removeAll(where: { $0 == secondCourse })
                        cleaneCourse.append(Course(dayOfWeek: course.dayOfWeek,
                                                   startTime: secondCourse.startTime,
                                                   endTime: course.endTime,
                                                   name: course.name,
                                                   classIDString: course.classIDString,
                                                   classPositionString: course.classPositionString,
                                                   classTeacherName: course.classTeacherName,
                                                   weekString: course.weekString))
                    }
                    if secondCourse.startTime == course.endTime + 1 {
                        cleaneCourse.removeAll(where: { $0 == course })
                        cleaneCourse.removeAll(where: { $0 == secondCourse })
                        cleaneCourse.append(Course(dayOfWeek: course.dayOfWeek,
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
                    cleaneCourse.removeAll(where: { $0 == course })
                    cleaneCourse.removeAll(where: { $0 == secondCourse })
                    cleaneCourse.append(Course(dayOfWeek: course.dayOfWeek,
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
        return cleaneCourse
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

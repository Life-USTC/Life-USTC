//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import SwiftUI
import SwiftyJSON

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    static var main = UstcUgAASClient()
    static let semesterIDList: [String: String] =
        ["2021年秋季学期": "221",
         "2022年春季学期": "241",
         "2022年夏季学期": "261",
         "2022年秋季学期": "281",
         "2023年春季学期": "301"]
    static let semesterDateList: [String: Date] =
        ["2021年秋季学期": .init(timeIntervalSince1970: 1_630_771_200),
         "2022年春季学期": .init(timeIntervalSince1970: 1_642_608_000),
         "2022年夏季学期": .init(timeIntervalSince1970: 1_656_172_800),
         "2022年秋季学期": .init(timeIntervalSince1970: 1_661_616_000),
         "2023年春季学期": .init(timeIntervalSince1970: 1_677_945_600)]

    var jsonCache = JSON() // save&load as /document/ugaas_cache.json
    var semesterID: String = "301"
    var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })!.key
    }

    var semesterDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterName })!.value
    }

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

    func saveToCalendar() {
        Course.saveToCalendar(courses, name: semesterName, startDate: semesterDate)
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

    init() {
        exceptionCall(loadCache)
    }
}

extension ContentView {
    func loadMainUstcUgAASClient() throws {
        UstcUgAASClient.main.semesterID = semesterID
    }
}

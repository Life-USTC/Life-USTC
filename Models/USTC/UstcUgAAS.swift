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

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    static var main = UstcUgAASClient()
    static let semesterIDList: [String: String] = ["2021年秋季学期": "221", "2022年春季学期": "241", "2022年夏季学期": "261", "2022年秋季学期": "281", "2023年春季学期": "301"]
    
    var jsonCache = JSON() // save&load as /document/ugaas_cache.json
    var semesterID: String = "281"
    var courses: [Course] = []

    /// Load /Document/ugaas_cache.json to self.jsonCache
    func loadCache() throws {
        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = path + "/ugaas_cache.json"
        if fileManager.fileExists(atPath: filePath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                jsonCache = try JSON(data: data)
        } else {
            _ = Task {
                try await forceUpdate()
            }
        }
    }

    /// Save /Document/ugaas_cache.json to self.jsonCache
    func saveCache() throws {
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
        var result: [Course] = []
        for (_, subJson): (String, JSON) in jsonCache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!, startTime: Int(subJson["startUnit"].stringValue)!, endTime: Int(subJson["endUnit"].stringValue)!, name: subJson["courseName"].stringValue, classIDString: subJson["courseCode"].stringValue, classPositionString: classPositionString, classTeacherName: subJson["teachers"][0].stringValue, weekString: subJson["weeksStr"].stringValue)

            result.append(tmp)
        }
        courses = result
        return result
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
        try saveCache()
    }

    func cleanUp() {
        courses.sort(by: { a, b in
            if a.dayOfWeek == b.dayOfWeek {
                if a.startTime == b.startTime {
                    return a.endTime < b.endTime
                }
                return a.startTime < b.startTime
            }
            return a.dayOfWeek < b.dayOfWeek
        })
    }

    func saveToCalendar() {
        var store = EKEventStore()
        store.requestAccess(to: .event) { _, _ in
        }
        for course in courses {

        }
    }

    init() {
        exceptionCall(loadCache)
    }
}

extension ContentView {
    func loadMainUstcUgAASClient() {
        UstcUgAASClient.main.semesterID = semesterID
    }
}

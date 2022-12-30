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

let semesterIDList: [String: String] = ["2021年秋季学期": "221", "2022年春季学期": "241", "2022年夏季学期": "261", "2022年秋季学期": "281", "2023年春季学期": "301"]

// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    var ustcCasClient: UstcCasClient
    var session = URLSession(configuration: .default)
    var jsonCache = JSON() // save&load as /document/ugaas_cache.json
    var semesterID: String = "281"
    var courses: [Course] = []

    func loadCache() {
        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = path + "/ugaas_cache.json"
        if fileManager.fileExists(atPath: filePath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                jsonCache = try JSON(data: data)
            } catch {
                print(error)
            }
        } else {
            _ = Task {
                try await forceUpdate()
            }
        }
    }

    func saveCache() {
        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let filePath = path + "/ugaas_cache.json"
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
            } catch {
                print(error)
            }
        }
        do {
            try jsonCache.rawData().write(to: URL(fileURLWithPath: filePath))
        } catch {
            print(error)
        }
    }

    func login() async throws {
        let result = await ustcCasClient.loginToCAS()
        if !result {
            return
        }
        print("Logged In")
        if let cookies = ustcCasClient.casCookie {
            session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcLoginUrl, mainDocumentURL: ustcLoginUrl)
        }
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
        saveCache()
    }

    func cleanUp() {
        courses.sorted(by: { a, b in
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
        for course in courses {}
    }

    init(ustcCasClient: UstcCasClient) {
        self.ustcCasClient = ustcCasClient
        loadCache()
    }
}

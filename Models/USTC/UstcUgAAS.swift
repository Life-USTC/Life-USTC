//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import Foundation
import SwiftyJSON
import SwiftUI

// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    var ustcCasClient: UstcCasClient
    var session = URLSession(configuration: .default)
    var jsonCache = JSON() // save&load as /document/ugaas_cache.json
    
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
        let (_, _) = try await session.data(for: request)
    }
    
    func getCurriculum(semesterID: String = "281") async throws -> [Course] {
        var result: [Course] = []
        for (_, subJson): (String, JSON) in self.jsonCache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!, startTime: Int(subJson["startUnit"].stringValue)!, endTime: Int(subJson["endUnit"].stringValue)!, name: subJson["courseName"].stringValue, classIDString: subJson["courseCode"].stringValue, classPositionString: classPositionString, classTeacherName: subJson["teachers"][0].stringValue, weekString: subJson["weeksStr"].stringValue)
            
            result.append(tmp)
        }
        
        return result
    }
    
    func forceUpdate(semesterID: String = "281") async throws {
        try await self.login()
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)
        let (_, response) = try await session.data(for: request)
        
        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID: String = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }
        
        let (data, _) = try await session.data(for: URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(semesterID)/print-data/\(tableID)?weekIndex=")!))
        self.jsonCache = try JSON(data: data)
        self.saveCache()
    }
    
    func getCurriculum(semesterID: String = "281", courses: Binding<[Course]>, status: Binding<AsyncViewStatus>) {
        _ = Task {
            do {
                courses.wrappedValue = try await getCurriculum(semesterID: semesterID)
                status.wrappedValue = .success
            } catch {
                status.wrappedValue = .failure
                print(error)
            }
        }
    }
    
    init(ustcCasClient: UstcCasClient) {
        self.ustcCasClient = ustcCasClient
        loadCache()
    }
}

//
//  CurriculumDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import EventKit
import SwiftUI
import SwiftyJSON
import WidgetKit

class CurriculumDelegate: UserDefaultsADD & LastUpdateADD {
    // Protocol requirements
    typealias D = [Course]
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASCurriculumCache"
    var timeCacheName: String = "UstcUgAASLastUpdatedCurriculum"
    var status: AsyncViewStatus = .inProgress {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    // Parent
    var ustcUgAASClient: UstcUgAASClient

    // See ExamDelegate.shared
    static var shared = CurriculumDelegate(.shared)

    // MARK: - Manually update these and saveCache()

    var cache = JSON()
    var data: [Course] = [] {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func parseCache() async throws -> [Course] {
        var result: [Course] = []
        for (_, subJson): (String, JSON) in cache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            // Course.init is expected to throw error for startTime/endTime OOB
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!,
                             startTime: Int(subJson["startUnit"].stringValue) ?? 1,
                             endTime: Int(subJson["endUnit"].stringValue) ?? 1,
                             name: subJson["courseName"].stringValue,
                             classIDString: subJson["courseCode"].stringValue,
                             classPositionString: classPositionString,
                             classTeacherName: subJson["teachers"][0].stringValue,
                             weekString: subJson["weeksStr"].stringValue)
            result.append(tmp)
        }
        return result
    }

    func forceUpdate() async throws {
        if try await !ustcUgAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }
        let (_, response) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(UstcUgAASClient.shared.semesterID)/print-data/\(tableID)?weekIndex=")!)
        cache = try JSON(data: data)

        try await afterForceUpdate()
    }

    func saveToCalendar() async throws {
        let courses = try await retrive()
        try await Course.saveToCalendar(courses,
                                        name: UstcUgAASClient.shared.semesterName,
                                        startDate: UstcUgAASClient.shared.semesterStartDate)
    }

    init(_ client: UstcUgAASClient) {
        ustcUgAASClient = client

        afterInit()
    }
}

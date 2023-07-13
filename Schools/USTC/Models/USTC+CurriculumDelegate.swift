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

final class USTCCurriculumDelegate: TimeListBasedCDP {
    static var shared = USTCCurriculumDelegate(.shared)

    // MARK: - Protocol requirements

    typealias D = Curriculum
    var lastUpdate: Date?
    var nameToShowWhenUpdate: String? = "Curriculum"
    var cacheName: String = "UstcUgAASCurriculumCache"
    var timeCacheName: String = "UstcUgAASLastUpdatedCurriculum"

    var lunchbreakTime: Int = 5
    var dinnerbreakTime: Int = 5
    let startTimes: [String] = ["07:50", "08:40", "09:45", "10:35", "11:25",
                                "14:00", "14:50", "15:55", "16:45", "17:35",
                                "19:30", "20:20", "21:10"]
    let endTimes: [String] = ["08:35", "09:25", "10:30", "11:20",
                              "12:10", "14:45", "15:35", "16:40", "17:30", "18:20",
                              "20:15", "21:05", "21:55"]
    @Published var status: AsyncViewStatus = .inProgress
    var ustcUgAASClient: UstcUgAASClient
    var cache = JSON()
    @Published var data: Curriculum = .init()

    func parseCache() async throws -> Curriculum {
        var result: [Course] = []
        for (_, subJson): (String, JSON) in cache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            // Course.init is expected to throw error for startTime/endTime OOB
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!,
                             startTime: Int(subJson["startUnit"].stringValue) ?? parseHHMMToInt(time: subJson["startDate"].stringValue, type: .startTime),
                             endTime: Int(subJson["endUnit"].stringValue) ?? parseHHMMToInt(time: subJson["endDate"].stringValue, type: .endTime),
                             startHHMM: subJson["startDate"].stringValue,
                             endHHMM: subJson["endDate"].stringValue,
                             name: subJson["courseName"].stringValue,
                             lessonCode: subJson["courseCode"].stringValue,
                             roomName: classPositionString,
                             buildingName: subJson["building"].stringValue,
                             teacherName: subJson["teachers"][0].stringValue,
                             weekString: subJson["weeksStr"].stringValue)
            result.append(tmp)
        }
        return Curriculum(semesterID: ustcUgAASClient.semesterID,
                          courses: result,
                          semesterName: ustcUgAASClient.semesterName,
                          semesterStartDate: ustcUgAASClient.semesterStartDate,
                          semesterEndDate: ustcUgAASClient.semesterEndDate,
                          semesterWeeks: ustcUgAASClient.semesterWeeks)
    }

    func forceUpdate() async throws {
        let queryURL = URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!
        if try await !ustcUgAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }
        let (_, response) = try await URLSession.shared.data(from: queryURL)

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

    init(_ client: UstcUgAASClient) {
        ustcUgAASClient = client

        afterInit()
    }
}

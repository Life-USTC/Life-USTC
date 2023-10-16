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

private func convertYYMMDD(_ date: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: date)!
}

class USTCCurriculumDelegate: CurriculumProtocolB {
    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]
    static let shared = USTCCurriculumDelegate()

    @LoginClient(.ustcUgAAS) var ugAASClient: UstcUgAASClient
    @LoginClient(.ustcCatalog) var catalogClient: UstcCatalogClient

    override func refreshSemesterBase() async throws -> [Semester] {
        let request = URLRequest(url: URL(string: "https://static.xzkd.online/curriculum/semesters.json")!)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode([Semester].self, from: data)
        return result
    }

    override func refreshSemester(inComplete: Semester) async throws -> Semester {
        return try await refreshUnderGraduateSemester(inComplete: inComplete)
    }

    func refreshUnderGraduateSemester(inComplete: Semester) async throws -> Semester {
        let queryURL = URL(
            string: "https://jw.ustc.edu.cn/for-std/course-table"
        )!
        // Step 0: Check login
        if try await !_ugAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        // Step 1: Get tableID, (usually 353802)
        var request = URLRequest(url: queryURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await URLSession.shared.data(for: request)

        let match = response.url?.absoluteString
            .matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match { if !match.isEmpty { tableID = String(match.first!.0) } }

        // Step 2: Get lessonIDs
        let url = URL(
            string:
                "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(inComplete.id)&dataId=\(tableID)"
        )!
        request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (baseData, _) = try await URLSession.shared.data(for: request)
        let baseJSON = try JSON(data: baseData)
        var lessonIDs = baseJSON["lessonIds"].arrayValue.map(\.stringValue)
        if additioanlCourseIDList.keys.contains(inComplete.id) {
            lessonIDs = lessonIDs + additioanlCourseIDList[inComplete.id]!.map { String($0) }
        }
        if lessonIDs.isEmpty { return inComplete }

        var courseList: [Course] = []
        for lessonID in lessonIDs {
            let lessonURL = URL(
                string: "https://static.xzkd.online/curriculum/\(inComplete.id)/\(lessonID).json"
            )
            let (courseJSONData, _) = try await URLSession.shared.data(from: lessonURL!)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let course = try decoder.decode(Course.self, from: courseJSONData)
            courseList.append(course)
        }

        var returnSemester = inComplete
        returnSemester.courses = courseList
        return returnSemester
    }
}

extension USTCExports {
    var ustcCurriculumBehavior: CurriculumBehavior {
        CurriculumBehavior(
            shownTimes: [470, 585, 680, 735, 850, 945, 1000, 1095],
            highLightTimes: [730, 995, 1145],
            convertTo: { value in
                value <= 730 ? value : value <= 1100 ? value - 105 : value - 170
            },
            convertFrom: { value in
                value <= 730 ? value : value <= 995 ? value + 105 : value + 170
            }
        )
    }
}

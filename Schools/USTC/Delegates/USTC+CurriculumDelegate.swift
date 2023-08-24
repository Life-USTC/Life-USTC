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

class USTCCurriculumDelegate: CurriculumProtocolB & ManagedRemoteUpdateProtocol {
    static let shared = USTCCurriculumDelegate()

    @LoginClient(.ustcUgAAS) var ugAASClient: UstcUgAASClient
    @LoginClient(.ustcCatalog) var catalogClient: UstcCatalogClient

    func refreshSemesterBase() async throws -> [Semester] {
        if try await !_catalogClient.requireLogin() {
            throw BaseError.runtimeError("UstcCatalog Not logined")
        }
        let validToken = catalogClient.token

        let url = URL(
            string: "https://catalog.ustc.edu.cn/api/teach/semester/list?access_token=\(validToken)"
        )!

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

        var result: [Semester] = []
        for (_, subJson) in json {
            result.append(
                Semester(
                    id: subJson["id"].stringValue,
                    courses: [],
                    name: subJson["nameZh"].stringValue,
                    startDate: convertYYMMDD(subJson["start"].stringValue),
                    endDate: convertYYMMDD(subJson["end"].stringValue)
                )
            )
        }

        return result
    }

    func refreshSemester(inComplete: Semester) async throws -> Semester {
        let queryURL = URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!
        // Step 0: Check login
        if try await !_ugAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        // Step 1: Get tableID, (usually 353802)
        var request = URLRequest(url: queryURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await URLSession.shared.data(for: request)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        // Step 2: Get lessonIDs
        let url = URL(
            string:
                "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(inComplete.id)&dataId=\(tableID)"
        )!
        request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (baseData, _) = try await URLSession.shared.data(for: request)
        let baseJSON = try JSON(data: baseData)
        let lessonIDs = baseJSON["lessonIds"].arrayValue.map(\.stringValue)
        if lessonIDs.isEmpty {
            return inComplete
        }

        // Step3: Get courses details
        let detailURL = URL(string: "https://jw.ustc.edu.cn/ws/schedule-table/datum")!
        request = URLRequest(url: detailURL)
        request.httpMethod = "POST"
        let params = ["lessonIds": lessonIDs]
        let paramsData = try JSONSerialization.data(withJSONObject: params, options: [])
        request.httpBody = paramsData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

        // Step4: Setup Lecutures:
        var lectureList: [String: [Lecture]] = [:]
        for (_, subJson) in json["result"]["scheduleList"] {
            let baseDate = convertYYMMDD(subJson["date"].stringValue)
            let startTime = subJson["startTime"].intValue
            let endTime = subJson["endTime"].intValue
            let startDate =
                baseDate + DateComponents(hour: startTime / 100, minute: startTime % 100)
            let endDate = baseDate + DateComponents(hour: endTime / 100, minute: endTime % 100)

            let location = subJson["room"]["code"].stringValue
            let teacher = subJson["personName"].stringValue
            let periods = subJson["periods"].doubleValue
            let lecture = Lecture(
                startDate: startDate,
                endDate: endDate,
                name: "",
                location: location,
                teacher: teacher,
                periods: periods
            )

            let courseID = subJson["lessonId"].stringValue
            // adding to lectureList
            if lectureList[courseID] == nil {
                lectureList[courseID] = [lecture]
            } else {
                lectureList[courseID]?.append(lecture)
            }
        }

        // Step 4: Load Course
        var courses: [Course] = []
        for (_, subJson) in baseJSON["lessons"] {
            let name = subJson["course"]["nameZh"].stringValue
            let code = subJson["code"].stringValue
            let courseCode = subJson["course"]["code"].stringValue
            let teachers = subJson["teacherAssignmentList"].arrayValue.map {
                $0["person"]["nameZh"].stringValue
            }
            let teacherName = teachers.joined(separator: ",")
            let description = subJson["scheduleGroupStr"].stringValue
            let credit = subJson["credits"].doubleValue

            let courseID = subJson["id"].stringValue
            var lectures = lectureList[courseID] ?? []
            lectures = lectures.map { lecture in
                var result = lecture
                result.name = name
                return result
            }

            let course = Course(
                name: name,
                courseCode: courseCode,
                lessonCode: code,
                teacherName: teacherName,
                lectures: lectures,
                description: description,
                credit: credit
            )
            courses.append(course)
        }

        var result = inComplete
        result.courses = courses
        return result
    }
}

let ustcCurriculumBehavior = CurriculumBehavior(
    shownTimes: [470, 585, 680, 735, 850, 945, 1000, 1095],
    highLightTimes: [730, 995, 1145],
    convertTo: { value in

        value <= 730 ? value : value <= 1100 ? value - 105 : value - 170

    },
    convertFrom: { value in

        value <= 730 ? value : value <= 995 ? value + 105 : value + 170
    }
)

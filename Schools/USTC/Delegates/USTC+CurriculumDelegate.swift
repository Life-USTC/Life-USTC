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

class USTCUndergraduateCurriculumDelegate: CurriculumProtocolB {
    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]
    static let shared = USTCUndergraduateCurriculumDelegate()

    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    override func refreshSemesterBase() async throws -> [Semester] {
        let request = URLRequest(url: URL(string: "\(staticURLPrefix)/curriculum/semesters.json")!)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode([Semester].self, from: data)
        return result
    }

    override func refreshSemester(inComplete: Semester) async throws -> Semester {
        let queryURL = URL(
            string: "https://jw.ustc.edu.cn/for-std/course-table"
        )!
        // Step 0: Check login
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        // Step 1: Get tableID, (usually 353802)
        var request = URLRequest(url: queryURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await URLSession.shared.data(for: request)

        guard
            let tableID = response.url?.absoluteString
                .matches(of: try! Regex(#"\d+"#))
                .first
                .map({ String($0.0) })
        else {
            throw BaseError.runtimeError("No tableID found in response URL")
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
        var lessonIDs = baseJSON["lessonIds"].arrayValue.map(\.stringValue)
        if additioanlCourseIDList.keys.contains(inComplete.id) {
            lessonIDs = lessonIDs + additioanlCourseIDList[inComplete.id]!.map { String($0) }
        }
        if lessonIDs.isEmpty { return inComplete }

        var courseList: [Course] = []
        for lessonID in lessonIDs {
            do {
                let lessonURL = URL(
                    string: "\(staticURLPrefix)/curriculum/\(inComplete.id)/\(lessonID).json"
                )
                let (courseJSONData, _) = try await URLSession.shared.data(from: lessonURL!)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let course = try decoder.decode(Course.self, from: courseJSONData)
                courseList.append(course)
            } catch {
                continue
            }
        }

        var returnSemester = inComplete
        returnSemester.courses = courseList
        return returnSemester
    }
}

class USTCGraduateCurriculumDelegate: CurriculumProtocolA<(semesterId: String, studentId: String, semester: Semester)> {
    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]

    static let shared = USTCGraduateCurriculumDelegate()

    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    override func refreshSemesterList() async throws -> [(semesterId: String, studentId: String, semester: Semester)] {
        var request = URLRequest(url: URL(string: "\(staticURLPrefix)/curriculum/semesters.json")!)
        var (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode([Semester].self, from: data)

        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-select/")!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        var (_, response) = try await URLSession.shared.data(for: request)
        let studentId = String(
            response.url?.absoluteString
                .matches(of: try! Regex(#"\d+"#))
                .first?
                .0 ?? "0"
        )

        request = URLRequest(
            url: URL(
                string: "https://jw.ustc.edu.cn/ws/for-std/course-select/open-turns?bizTypeId=3&studentId=\(studentId)"
            )!
        )
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpMethod = "POST"
        (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)
        debugPrint(json)

        // if empty json, raise error
        if json.arrayValue.isEmpty {
            throw BaseError.runtimeError("No semester data")
        }

        let semesterId = json[0]["id"].stringValue
        let semesterName = json[0]["semesterName"].stringValue
        let semester = result.first { $0.name == semesterName }
        if semester == nil {
            throw BaseError.runtimeError("No semester data")
        }

        return [(semesterId, studentId, semester!)]
    }

    override func refreshSemester(id: (semesterId: String, studentId: String, semester: Semester)) async throws
        -> Semester
    {
        let url = URL(
            string:
                "https://jw.ustc.edu.cn/ws/for-std/course-select/selected-lessons?studentId=\(id.studentId)&turnId=\(id.semesterId)"
        )!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

        let lessonIDs = json.arrayValue.map { $0["id"].stringValue }

        let inComplete = id.semester

        var courseList: [Course] = []
        for lessonID in lessonIDs {
            do {
                let lessonURL = URL(
                    string: "\(staticURLPrefix)/curriculum/\(inComplete.id)/\(lessonID).json"
                )
                let (courseJSONData, _) = try await URLSession.shared.data(from: lessonURL!)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let course = try decoder.decode(Course.self, from: courseJSONData)
                courseList.append(course)
            } catch {
                continue
            }
        }

        var returnSemester = inComplete
        returnSemester.courses = courseList
        return returnSemester
    }
}

extension USTCExports {
    var curriculumChartShouldHideEvening: Bool {
        UserDefaults.appGroup.value(forKey: "curriculumChartShouldHideEvening") as? Bool ?? false
    }

    var ustcCurriculumBehavior: CurriculumBehavior {
        if curriculumChartShouldHideEvening {
            CurriculumBehavior(
                shownTimes: [
                    7 * 60 + 50,
                    9 * 60 + 45,
                    11 * 60 + 20,
                    14 * 60 + 0 - 105,
                    15 * 60 + 55 - 105,
                    17 * 60 + 30 - 105,
                ],
                highLightTimes: [
                    12 * 60 + 10,
                    18 * 60 + 20 - 105,
                ],
                convertTo: { value in
                    value <= 730 ? value : value - 105
                },
                convertFrom: { value in
                    value <= 730 ? value : value + 105
                }
            )
        } else {
            CurriculumBehavior(
                shownTimes: [
                    7 * 60 + 50,
                    9 * 60 + 45,
                    11 * 60 + 20,
                    14 * 60 + 0 - 105,
                    15 * 60 + 55 - 105,
                    17 * 60 + 30 - 105,
                    19 * 60 + 30 - 105 - 65,
                    21 * 60 + 5 - 105 - 65,
                ],
                highLightTimes: [
                    12 * 60 + 10,
                    18 * 60 + 20 - 105,
                    21 * 60 + 55 - 105 - 65,
                ],
                convertTo: { value in
                    value <= 730 ? value : value <= 1100 ? value - 105 : value - 170
                },
                convertFrom: { value in
                    value <= 730 ? value : value <= 995 ? value + 105 : value + 170
                }
            )
        }
    }
}

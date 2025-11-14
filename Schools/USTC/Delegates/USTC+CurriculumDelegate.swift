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

class USTCUndergraduateCurriculumDelegate: CurriculumProtocolBySemeter {
    static let shared = USTCUndergraduateCurriculumDelegate()

    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]

    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    let session = URLSession.shared

    override func refreshIncompleteSemesterList() async throws -> [Semester] {
        let (data, _) = try await session.data(
            from: URL(string: "\(staticURLPrefix)/curriculum/semesters.json")!
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode([Semester].self, from: data)

        return result
    }

    override func refreshSemester(inComplete: Semester) async throws -> Semester {
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let studentID = try await {
            let (_, response) = try await session.data(
                from: URL(
                    string: "https://jw.ustc.edu.cn/for-std/course-table"
                )!
            )

            return response.url?.absoluteString
                .matches(of: try! Regex(#"\d+"#))
                .first
                .map({ String($0.0) })
        }()

        guard let studentID else {
            throw BaseError.runtimeError("Cannot get student ID")
        }

        let courseIDs = try await {
            let (data, _) = try await session.data(
                from: URL(
                    string:
                        "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(inComplete.id)&dataId=\(studentID)"
                )!
            )
            let json = try JSON(data: data)
            var courseIDs = json["lessonIds"].arrayValue.map(\.stringValue)

            if additionalCourseIDList.keys.contains(inComplete.id) {
                let additionalIDs = additionalCourseIDList[inComplete.id]!.map { String($0) }
                courseIDs = Array(Set(courseIDs + additionalIDs))
            }

            return courseIDs
        }()

        let courses = try? await withThrowingTaskGroup(of: Course.self) { group in
            for courseID in courseIDs {
                group.addTask {
                    let (data, _) = try await self.session.data(
                        from: URL(string: "\(staticURLPrefix)/curriculum/\(inComplete.id)/\(courseID).json")!
                    )

                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    return try decoder.decode(Course.self, from: data)
                }
            }

            return try await group.reduce(into: [Course]()) { partialResult, course in
                partialResult.append(course)
            }
        }

        guard let courses else {
            throw BaseError.runtimeError("No course data")
        }

        var result = inComplete
        result.courses = courses
        return result
    }
}

class USTCGraduateCurriculumDelegate: CurriculumProtocolBySemeter {
    static let shared = USTCGraduateCurriculumDelegate()

    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]

    @LoginClient(.ustcCAS) var casClient: UstcCasClient

    let session = URLSession.shared

    override func refreshIncompleteSemesterList() async throws -> [Semester] {
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "\(staticURLPrefix)/curriculum/semesters.json")!
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode([Semester].self, from: data)

        return result
    }

    override func refreshSemester(inComplete: Semester) async throws -> Semester {
        if !inComplete.isCurrent {
            throw BaseError.runtimeError("Graduate curriculum only supports current semester")
        }

        if !(try await _casClient.requireLogin()) {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        _ = try await session.data(
            from: URL(
                string:
                    "https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https://app.ustc.edu.cn/site/examManage/index&from=wap"
            )!
        )

        _ = try await session.data(
            from: URL(
                string:
                    "https://id.ustc.edu.cn/cas/login?service=https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https%3A%2F%2Fapp.ustc.edu.cn%2Fsite%2FtimeTableQuery%2Findex&from=wap"
            )!
        )

        let course_names = try await {
            let (data, _) = try await session.data(
                from: URL(
                    string:
                        "https://app.ustc.edu.cn/xkjg/wap/default/get-index"
                )!
            )
            let json = try JSON(data: data)
            return json["d"]["lists"].arrayValue.map { $0["course_name"].stringValue }
        }()

        let courseCodeRegex = /\((.*?)\)/

        let courseCodes = course_names.compactMap { name -> String? in
            let match = try? courseCodeRegex.firstMatch(in: name)
            return match.map { String($0.1) }
        }

        let courseIDs = try await {
            let (semester_data, _) = try await session.data(
                from:
                    URL(string: "\(staticURLPrefix)/curriculum/\(inComplete.id)/courses.json")!
            )
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let all_courses = try decoder.decode([Course].self, from: semester_data)

            var courseIDs =
                all_courses.filter { course in
                    courseCodes.contains(course.lessonCode)
                }
                .map { String($0.id) }

            if additionalCourseIDList.keys.contains(inComplete.id) {
                let additionalIDs = additionalCourseIDList[inComplete.id]!.map { String($0) }
                courseIDs = Array(Set(courseIDs + additionalIDs))
            }

            return courseIDs
        }()

        let courses = try? await withThrowingTaskGroup(of: Course.self) { group in
            for courseID in courseIDs {
                group.addTask {
                    let (data, _) = try await self.session.data(
                        from: URL(string: "\(staticURLPrefix)/curriculum/\(inComplete.id)/\(courseID).json")!
                    )

                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    return try decoder.decode(Course.self, from: data)
                }
            }

            return try await group.reduce(into: [Course]()) { partialResult, course in
                partialResult.append(course)
            }
        }

        guard let courses else {
            throw BaseError.runtimeError("No course data")
        }

        var result = inComplete
        result.courses = courses
        return result
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

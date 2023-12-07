//
//  USTCScoreDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftyJSON

class USTCScoreDelegate: ManagedRemoteUpdateProtocol<Score> {
    static let shared = USTCScoreDelegate()

    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    override func refresh() async throws -> Score {
        let scoreURL = URL(
            string:
                "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=1&semesterIds"
        )!
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        var request = URLRequest(url: scoreURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let cache = try JSON(data: data)

        var result = Score()
        let subJson = cache["stdGradeRank"]
        result.gpa = cache["overview"]["gpa"].double ?? 0
        result.majorName = subJson["majorName"].string ?? "Error"
        result.majorRank = subJson["majorRank"].int ?? 0
        result.majorStdCount = subJson["majorStdCount"].int ?? 0
        result.courses = cache["semesters"]
            .flatMap { _, semesterJSON in
                semesterJSON["scores"]
                    .map { _, courseJSON in
                        CourseScore(
                            courseName: courseJSON["courseNameCh"].stringValue,
                            courseCode: courseJSON["courseCode"].stringValue,
                            lessonCode: courseJSON["lessonCode"].stringValue,
                            semesterID: courseJSON["semesterAssoc"].stringValue,
                            semesterName: courseJSON["semesterCh"].stringValue,
                            credit: Double(courseJSON["credits"].stringValue)!,
                            gpa: Double(courseJSON["gp"].stringValue),
                            score: courseJSON["scoreCh"].stringValue
                        )
                    }
            }
        return result
    }
}

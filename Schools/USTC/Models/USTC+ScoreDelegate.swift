//
//  USTCScoreDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftyJSON

final class USTCScoreDelegate: ScoreDelegateProtocol {
    static var shared = USTCScoreDelegate(.shared)

    // MARK: - Protocol requirements

    typealias D = Score
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASScoreCache"
    var timeCacheName: String = "UstcUgAASLastUpdateScores"
    @Published var status: AsyncViewStatus = .inProgress
    var ustcUgAASClient: UstcUgAASClient
    var cache = JSON()
    @Published var data: Score = .init()
    var placeHolderData: Score = .example

    // MARK: - Start reading from here:

    func parseCache() async throws -> Score {
        var result = Score()
        let subJson = cache["stdGradeRank"]
        result.gpa = cache["overview"]["gpa"].double ?? 0
        result.majorName = subJson["majorName"].string ?? "Error"
        result.majorRank = subJson["majorRank"].int ?? 0
        result.majorStdCount = subJson["majorStdCount"].int ?? 0
        result.courses = cache["semesters"].flatMap { _, semesterJSON in
            semesterJSON["scores"].map { _, courseJSON in
                CourseScore(courseName: courseJSON["courseNameCh"].stringValue,
                            courseCode: courseJSON["courseCode"].stringValue,
                            lessonCode: courseJSON["lessonCode"].stringValue,
                            semesterID: Int(courseJSON["semesterAssoc"].stringValue)!,
                            semesterName: courseJSON["semesterCh"].stringValue,
                            credit: Double(courseJSON["credits"].stringValue)!,
                            gpa: Double(courseJSON["gp"].stringValue),
                            score: courseJSON["scoreCh"].stringValue)
            }
        }

        return result
    }

    func refreshCache() async throws {
        if try await !ustcUgAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=1&semesterIds")!)

        let (data, _) = try await session.data(for: request)
        cache = try JSON(data: data)

        try await afterRefreshCache()
    }

    init(_ client: UstcUgAASClient) {
        ustcUgAASClient = client

        afterInit()
    }
}

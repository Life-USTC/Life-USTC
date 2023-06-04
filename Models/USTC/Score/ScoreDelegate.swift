//
//  ScoreDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftyJSON

class ScoreDelegate: UserDefaultsADD {
    // Protocol requirements
    typealias D = Score
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASScoreCache"
    var timeCacheName: String = "UstcUgAASLastUpdateScores"
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
    static var shared = ScoreDelegate(.shared)

    // MARK: - Manually update these and saveCache()

    var cache = JSON()
    var data: Score = .init() {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func parseCache() async throws -> Score {
        var result = Score()
        let subJson = cache["stdGradeRank"]
        result.gpa = cache["overview"]["gpa"].double ?? 0
        result.majorName = subJson["majorName"].string ?? "Error"
        result.majorRank = subJson["majorRank"].int ?? 0
        result.majorStdCount = subJson["majorStdCount"].int ?? 0

        var courseScoreList: [CourseScore] = []
        for (_, semesterJson): (String, JSON) in cache["semesters"] {
            for (_, courseScoreJson): (String, JSON) in semesterJson["scores"] {
                courseScoreList.append(CourseScore(courseName: courseScoreJson["courseNameCh"].stringValue,
                                                   courseCode: courseScoreJson["courseCode"].stringValue,
                                                   credit: Double(courseScoreJson["credits"].stringValue)!,
                                                   gpa: Double(courseScoreJson["gp"].stringValue),
                                                   lessonCode: courseScoreJson["lessonCode"].stringValue,
                                                   score: courseScoreJson["scoreCh"].stringValue,
                                                   semesterID: Int(courseScoreJson["semesterAssoc"].stringValue)!,
                                                   semesterName: courseScoreJson["semesterCh"].stringValue))
            }
        }
        result.courseScores = courseScoreList
        return result
    }

    func forceUpdate() async throws {
        if try await !ustcUgAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=1&semesterIds")!)

        let (data, _) = try await session.data(for: request)
        cache = try JSON(data: data)

        try await afterForceUpdate()
    }

    init(_ client: UstcUgAASClient) {
        ustcUgAASClient = client

        afterInit()
    }
}

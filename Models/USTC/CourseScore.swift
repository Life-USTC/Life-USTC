//
//  CourseScore.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import Foundation
import SwiftyJSON

struct CourseScore: Identifiable {
    var id = UUID()
    var courseName: String
    var courseCode: String
    var credit: Double
    var gpa: Double?
    var lessonCode: String
    var score: String
    var semesterID: Int
    var semesterName: String
}

struct Score {
    var courseScores: [CourseScore] = []
    var gpa: Double = 0.0
    var majorRank: Int = 0
    var majorStdCount: Int = 0
    var majorName: String = ""
}

class ScoreDelegate: CacheAsyncDataDelegate {
    typealias D = Score
    var lastUpdate: Date?
    var timeInterval: Double?
    var cacheName: String = "UstcUgAASScoreCache"
    var timeCacheName: String = "UstcUgAASLastUpdateScores"

    var cache = JSON()

    func parseCache() async throws -> Score {
        var result = Score()
        let subJson = cache["stdGradeRank"]
        result.gpa = subJson["gpa"].double ?? 0
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
                                                   score: courseScoreJson["score"].stringValue,
                                                   semesterID: Int(courseScoreJson["semesterAssoc"].stringValue)!,
                                                   semesterName: courseScoreJson["semesterCh"].stringValue))
            }
        }
        result.courseScores = courseScoreList
        return result
    }

    func forceUpdate() async throws {
        try await UstcUgAASClient.main.login()
        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?semesterIds")!)

        let (data, _) = try await session.data(for: request)
        cache = try JSON(data: data)
        lastUpdate = Date()
        try saveCache()
    }

    init() {
        exceptionCall {
            try self.loadCache()
        }
    }
}

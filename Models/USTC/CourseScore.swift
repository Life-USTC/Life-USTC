//
//  CourseScore.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import Foundation

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

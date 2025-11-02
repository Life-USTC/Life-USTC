//
//  Score.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI
import SwiftyJSON

/// Store score for one course
struct CourseScore: Codable {
    // MARK: - Information about the course itself

    /// - Important:
    /// You are supposed to localize this, see documents on localization.
    var courseName: String

    /// Code that could be reused/shared, like MATH10001
    ///
    /// - Important:
    /// Shown on UI, please set a limit to length.
    var courseCode: String

    /// Code to indicate which exact lesson the student is taking, like MATH10001.01
    ///
    /// - Description:
    /// When user receives upgrade on this course, the server will get notified,
    /// which would then notify other users who haven't checked their score.
    /// So make sure that this is identically provided on Score & Course.
    ///
    /// - Important:
    /// Avoid using `.` as `semesterID.lessonCode` is used to notify user.
    var lessonCode: String

    /// Used to group semesters, smaller id comes first in time
    ///
    /// - Description:
    /// In USTC, this looks like this (you don't have to match this), however you do have to match with the IDs you provide in Course.
    /// 221: 2021 Fall
    /// 241: 2022 Spring
    var semesterID: String

    /// - Important: Shown on UI
    var semesterName: String

    // MARK: - Information about the score

    /// How much the course is valued, like 2.0 / 0.5
    var credit: Double

    /// Provide nil for a pass/fail only score
    var gpa: Double?

    /// The given grade, for example 95 / 61, or Passed/Failed
    ///
    /// - Important:
    /// Shown on UI
    ///
    /// - Description:
    /// ## UI apperance
    /// If this is identical to GPA, or other reason you don't want to present on UI, simply leave empty.
    ///
    /// ## Localizations
    /// Some notations are localized, such as 通过 <=> Passed, 未通过 <=>Failed
    /// Meaning that you don't have to localization on your own
    /// Try convert to this standard, or file issue on GitHub.
    var score: String

    init(
        courseName: String,
        courseCode: String,
        lessonCode: String,
        semesterID: String,
        semesterName: String,
        credit: Double,
        gpa: Double? = nil,
        score: String
    ) {
        self.courseName = courseName
        self.courseCode = courseCode
        self.lessonCode = lessonCode
        self.semesterID = semesterID
        self.semesterName = semesterName
        self.credit = credit
        self.gpa = gpa
        self.score = score
    }

    static let example = CourseScore(
        courseName: "数学分析 B1",
        courseCode: "MATH10001",
        lessonCode: "MATH10001.01",
        semesterID: "221",
        semesterName: "2021 春季学期",
        credit: 3.0,
        gpa: 4.3,
        score: "95"
    )
}

struct Score: Codable, ExampleDataProtocol {
    /// List of course, default order matters for UI.
    var courses: [CourseScore]

    /// Total GPA
    var gpa: Double

    // MARK: - Ranking Information

    var majorRank: Int
    var majorStdCount: Int
    var majorName: String

    var additionalMessage: String?

    init(
        courses: [CourseScore] = [],
        gpa: Double = 0.0,
        majorRank: Int = 0,
        majorStdCount: Int = 0,
        majorName: String = "",
        additionalMessage: String? = nil
    ) {
        self.courses = courses
        self.gpa = gpa
        self.majorRank = majorRank
        self.majorStdCount = majorStdCount
        self.majorName = majorName
        self.additionalMessage = additionalMessage
    }

    static let example = Score(
        courses: [
            CourseScore(
                courseName: "数学分析 B1",
                courseCode: "MATH1006",
                lessonCode: "MATH1006.02",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 6.0,
                gpa: 4.3,
                score: "95"
            ),
            CourseScore(
                courseName: "线性代数 A",
                courseCode: "MATH1002",
                lessonCode: "MATH1002-02",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 4.0,
                gpa: 4.0,
                score: "90"
            ),
            CourseScore(
                courseName: "大学物理 B1",
                courseCode: "PHYS1001",
                lessonCode: "PHYS1001-03",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 4.0,
                gpa: 3.7,
                score: "85"
            ),
            CourseScore(
                courseName: "程序设计 II",
                courseCode: "CS1002",
                lessonCode: "CS1002-01",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 3.0,
                gpa: 4.3,
                score: "96"
            ),
            CourseScore(
                courseName: "英语写作",
                courseCode: "ENGL1001",
                lessonCode: "ENGL1001-05",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 2.0,
                gpa: 3.3,
                score: "80"
            ),
            CourseScore(
                courseName: "思想道德与法治",
                courseCode: "POLI1001",
                lessonCode: "POLI1001-02",
                semesterID: "221",
                semesterName: "2023 秋季学期",
                credit: 3.0,
                gpa: 4.0,
                score: "90"
            ),
            CourseScore(
                courseName: "体育 I",
                courseCode: "PE1001",
                lessonCode: "PE1001-08",
                semesterID: "221",
                semesterName: "2023 秋季学期",
                credit: 1.0,
                gpa: nil,
                score: "通过"
            ),
        ],
        gpa: 3.94,
        majorRank: 15,
        majorStdCount: 180,
        majorName: "计算机科学与技术"
    )
}

typealias ScoreDelegateProtocol = ManagedRemoteUpdateProtocol<Score>

extension ManagedDataSource<Score> {
    static let score = ManagedDataSource(
        local: ManagedLocalStorage("Score"),
        remote: SchoolExport.shared.scoreDelegate
    )
}

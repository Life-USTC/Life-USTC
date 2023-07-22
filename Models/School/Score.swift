//
//  CourseScore.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI
import SwiftyJSON

/// Store score for one course
struct CourseScore: Identifiable, Equatable {
    var id: String {
        lessonCode
    }

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
    var semesterID: Int

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

    init(courseName: String,
         courseCode: String,
         lessonCode: String,
         semesterID: Int,
         semesterName: String,
         credit: Double,
         gpa: Double? = nil,
         score: String)
    {
        self.courseName = courseName
        self.courseCode = courseCode
        self.lessonCode = lessonCode
        self.semesterID = semesterID
        self.semesterName = semesterName
        self.credit = credit
        self.gpa = gpa
        self.score = score
    }
}

struct Score: Equatable {
    /// List of course, default order matters for UI.
    var courses: [CourseScore]

    /// Total GPA
    var gpa: Double

    // MARK: - Ranking Information

    var majorRank: Int
    var majorStdCount: Int
    var majorName: String

    var additionalMessage: String?

    init(courses: [CourseScore] = [],
         gpa: Double = 0.0,
         majorRank: Int = 0,
         majorStdCount: Int = 0,
         majorName: String = "",
         additionalMessage: String? = nil)
    {
        self.courses = courses
        self.gpa = gpa
        self.majorRank = majorRank
        self.majorStdCount = majorStdCount
        self.majorName = majorName
        self.additionalMessage = additionalMessage
    }
}

protocol ScoreDelegateProtocol: ObservableObject, UserDefaultsADD & LastUpdateADD & NotifyUserWhenUpdateADD where D.Type == Score.Type {}

extension ScoreDelegateProtocol {
    var nameToShowWhenUpdate: String {
        "Score"
    }
}

extension CourseScore {
    static var example = CourseScore(courseName: "数学分析B1",
                                     courseCode: "MATH10001",
                                     lessonCode: "MATH10001.01",
                                     semesterID: 221,
                                     semesterName: "2021春季学期",
                                     credit: 3.0,
                                     gpa: 4.3,
                                     score: "95")
}

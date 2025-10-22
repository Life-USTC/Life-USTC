//
//  CourseScore.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI
import SwiftyJSON

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
        courses: [.example],
        gpa: 4.3,
        majorRank: 1,
        majorStdCount: 100,
        majorName: "废理兴工"
    )
}

typealias ScoreDelegateProtocol = ManagedRemoteUpdateProtocol<Score>

extension ManagedDataSource<Score> {
    static let score = ManagedDataSource(
        local: ManagedLocalStorage("Score"),
        remote: SchoolExport.shared.scoreDelegate
    )
}

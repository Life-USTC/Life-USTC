//
//  Semester.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation

struct Semester: Codable, Identifiable, Equatable {
    var id: String
    var courses: [Course]
    var name: String
    var startDate: Date
    var endDate: Date

    static let example = Semester(
        id: "251",
        courses: [
            .example,
            .example2,
            .example3,
            .example4,
        ],
        name: "2025 秋季学期",
        startDate: Date().stripTime().add(day: -30),
        endDate: Date().stripTime().add(day: 120)
    )

    var isCurrent: Bool {
        let today = Date().stripTime()
        return (startDate ... endDate).contains(today)
    }
}

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
        id: "241",
        courses: [.example],
        name: "2021 Spring",
        startDate: Date(),
        endDate: Date().add(day: 10)
    )
}

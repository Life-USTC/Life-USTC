//
//  Course.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import SwiftUI

private let courseColors: [Color] = [.orange, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]

class Course: Codable, Identifiable, Equatable {
    private var insideId: Int = 0
    var id: Int = 0
    var name: String
    var courseCode: String
    var lessonCode: String
    var teacherName: String
    var lectures: [Lecture]
    var description: String? = ""
    var credit: Double = 0
    var additionalInfo: [String: String] = [:]
    var dateTimePlacePersonText: String? = ""

    func color() -> Color {
        return courseColors[id % courseColors.count]
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case courseCode
        case lessonCode
        case teacherName
        case lectures
        case description
        case credit
        case additionalInfo
        case dateTimePlacePersonText
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        courseCode = try container.decode(String.self, forKey: .courseCode)
        lessonCode = try container.decode(String.self, forKey: .lessonCode)
        teacherName = try container.decode(String.self, forKey: .teacherName)
        lectures = try container.decode([Lecture].self, forKey: .lectures)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        credit = try container.decode(Double.self, forKey: .credit)
        additionalInfo = try container.decode([String: String].self, forKey: .additionalInfo)
        dateTimePlacePersonText = try container.decodeIfPresent(String.self, forKey: .dateTimePlacePersonText)

        for lecture in lectures {
            lecture.course = self
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(courseCode, forKey: .courseCode)
        try container.encode(lessonCode, forKey: .lessonCode)
        try container.encode(teacherName, forKey: .teacherName)
        try container.encode(lectures, forKey: .lectures)
        try container.encode(description, forKey: .description)
        try container.encode(credit, forKey: .credit)
        try container.encode(additionalInfo, forKey: .additionalInfo)
        try container.encode(dateTimePlacePersonText, forKey: .dateTimePlacePersonText)
    }

    init(
        id: Int = 0,
        name: String,
        courseCode: String,
        lessonCode: String,
        teacherName: String,
        lectures: [Lecture],
        description: String? = "",
        credit: Double = 0,
        additionalInfo: [String: String] = [:],
        dateTimePlacePersonText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
        self.lessonCode = lessonCode
        self.teacherName = teacherName
        self.lectures = lectures
        self.description = description
        self.credit = credit
        self.additionalInfo = additionalInfo
        self.dateTimePlacePersonText = dateTimePlacePersonText

        for lecture in lectures {
            lecture.course = self
        }
    }

    static let example = Course(
        name: "数学分析 B1",
        courseCode: "MATH10001",
        lessonCode: "MATH10001.01",
        teacherName: "程艺",
        lectures: [.example],
        credit: 6
    )
}

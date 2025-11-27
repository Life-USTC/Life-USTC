//
//  Course.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import SwiftData
import SwiftUI

@Model
final class Course {
    @Attribute(.unique) var id: Int = 0

    @Relationship var semester: Semester?

    var name: String
    var courseCode: String
    var lessonCode: String
    var teacherName: String
    var detailText: String? = ""
    var credit: Double = 0
    var additionalInfo: [String: String] = [:]
    var dateTimePlacePersonText: String? = ""

    var color: Color {
        let courseColors: [Color] = [.orange, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]
        return courseColors[id.hashValue % courseColors.count]
    }

    init(
        id: Int = 0,
        name: String,
        courseCode: String,
        lessonCode: String,
        teacherName: String,
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
        self.detailText = description
        self.credit = credit
        self.additionalInfo = additionalInfo
        self.dateTimePlacePersonText = dateTimePlacePersonText
    }
}

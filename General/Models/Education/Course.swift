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
    var semester: Semester?
    @Relationship(deleteRule: .cascade, inverse: \Lecture.course) var lectures: [Lecture] = []

    @Attribute(.unique) var jw_id: Int
    var name: String
    var courseCode: String
    var lessonCode: String
    var teacherName: String
    var detailText: String?
    var credit: Double
    var additionalInfo: [String: String]
    var dateTimePlacePersonText: String?

    var color: Color {
        let courseColors: [Color] = [.orange, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown]
        return courseColors[jw_id % courseColors.count]
    }

    init(
        jw_id: Int,
        name: String,
        courseCode: String,
        lessonCode: String,
        teacherName: String,
        description: String? = "",
        credit: Double = 0,
        additionalInfo: [String: String] = [:],
        dateTimePlacePersonText: String? = nil
    ) {
        self.jw_id = jw_id
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

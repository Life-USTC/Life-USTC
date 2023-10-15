//
//  Course.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import Foundation

struct Course: Codable, Identifiable, Equatable {
    var id: Int = 0
    var name: String
    var courseCode: String
    var lessonCode: String
    var teacherName: String
    var lectures: [Lecture]
    var description: String? = ""
    var credit: Double = 0
    var additionalInfo: [String: String] = [:]

    static let example = Course(
        name: "数学分析B1",
        courseCode: "MATH10001",
        lessonCode: "MATH10001.01",
        teacherName: "程艺",
        lectures: [.example],
        credit: 6
    )
}

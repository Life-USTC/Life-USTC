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
        id: 15661,
        name: "数学分析 B1",
        courseCode: "MATH1006",
        lessonCode: "MATH1006.02",
        teacherName: "程艺",
        lectures: [
            Lecture(
                startDate: Date().startOfWeek().add(day: 1) + DateComponents(hour: 9, minute: 45),
                endDate: Date().startOfWeek().add(day: 1) + DateComponents(hour: 11, minute: 20),
                name: "数学分析 B1",
                location: "5104",
                teacherName: "程艺",
                periods: 2,
                startIndex: 3,
                endIndex: 4
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 3) + DateComponents(hour: 9, minute: 45),
                endDate: Date().startOfWeek().add(day: 3) + DateComponents(hour: 11, minute: 20),
                name: "数学分析 B1",
                location: "5104",
                teacherName: "程艺",
                periods: 2,
                startIndex: 3,
                endIndex: 4
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 5) + DateComponents(hour: 9, minute: 45),
                endDate: Date().startOfWeek().add(day: 5) + DateComponents(hour: 11, minute: 20),
                name: "数学分析 B1",
                location: "5104",
                teacherName: "程艺",
                periods: 2,
                startIndex: 3,
                endIndex: 4
            ),
        ],
        credit: 6
    )

    static let example2 = Course(
        id: 15249,
        name: "力学 A",
        courseCode: "PHYS1001A",
        lessonCode: "PHYS1001A.01",
        teacherName: "李阳",
        lectures: [
            Lecture(
                startDate: Date().startOfWeek().add(day: 2) + DateComponents(hour: 9, minute: 45),
                endDate: Date().startOfWeek().add(day: 2) + DateComponents(hour: 11, minute: 20),
                name: "力学 A",
                location: "5102",
                teacherName: "李阳",
                periods: 2,
                startIndex: 3,
                endIndex: 4
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 4) + DateComponents(hour: 7, minute: 50),
                endDate: Date().startOfWeek().add(day: 4) + DateComponents(hour: 9, minute: 25),
                name: "力学 A",
                location: "5102",
                teacherName: "李阳",
                periods: 2,
                startIndex: 1,
                endIndex: 2
            ),
        ],
        credit: 4
    )

    static let example3 = Course(
        id: 20832,
        name: "计算机程序设计 A",
        courseCode: "CS1001A",
        lessonCode: "CS1001A.H1",
        teacherName: "孙广中",
        lectures: [
            Lecture(
                startDate: Date().startOfWeek().add(day: 1) + DateComponents(hour: 19, minute: 30),
                endDate: Date().startOfWeek().add(day: 1) + DateComponents(hour: 21, minute: 55),
                name: "计算机程序设计 A",
                location: "西活二楼机房",
                teacherName: "孙广中",
                periods: 3,
                startIndex: 11,
                endIndex: 13
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 2) + DateComponents(hour: 15, minute: 55),
                endDate: Date().startOfWeek().add(day: 2) + DateComponents(hour: 17, minute: 30),
                name: "计算机程序设计 A",
                location: "5306",
                teacherName: "孙广中",
                periods: 2,
                startIndex: 8,
                endIndex: 9
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 5) + DateComponents(hour: 14, minute: 00),
                endDate: Date().startOfWeek().add(day: 5) + DateComponents(hour: 15, minute: 35),
                name: "计算机程序设计 A",
                location: "5306",
                teacherName: "孙广中",
                periods: 2,
                startIndex: 6,
                endIndex: 7
            ),
        ],
        credit: 4
    )

    static let example4 = Course(
        id: 16000,
        name: "大学物理-综合实验 B",
        courseCode: "PHYS1009B",
        lessonCode: "PHYS1009B.02",
        teacherName:
            "代如成, 刘应玲, 吴玉椿, 孙晓宇, 宋国锋, 岳盈, 张乔枫, 张华洋, 张增明, 张权, 张杨, 曲广媛, 曾华凌, 李恒一, 梁燕, 沈镇, 浦其荣, 王中平, 王晓方, 王鹤, 祝巍, 胡晓敏, 蔡俊, 赵伟, 赵霞, 郭玉刚, 陶小平, 韦先涛",
        lectures: [
            Lecture(
                startDate: Date().startOfWeek().add(day: 0) + DateComponents(hour: 19, minute: 30),
                endDate: Date().startOfWeek().add(day: 0) + DateComponents(hour: 21, minute: 55),
                name: "大学物理-综合实验 B",
                location: "东区教1楼物理实验室",
                teacherName:
                    "代如成, 刘应玲, 吴玉椿, 孙晓宇, 宋国锋, 岳盈, 张乔枫, 张华洋, 张增明, 张权, 张杨, 曲广媛, 曾华凌, 李恒一, 梁燕, 沈镇, 浦其荣, 王中平, 王晓方, 王鹤, 祝巍, 胡晓敏, 蔡俊, 赵伟, 赵霞, 郭玉刚, 陶小平, 韦先涛",
                periods: 3,
                startIndex: 11,
                endIndex: 13
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 6) + DateComponents(hour: 19, minute: 30),
                endDate: Date().startOfWeek().add(day: 6) + DateComponents(hour: 21, minute: 55),
                name: "大学物理-综合实验 B",
                location: "东区教1楼物理实验室",
                teacherName:
                    "代如成, 刘应玲, 吴玉椿, 孙晓宇, 宋国锋, 岳盈, 张乔枫, 张华洋, 张增明, 张权, 张杨, 曲广媛, 曾华凌, 李恒一, 梁燕, 沈镇, 浦其荣, 王中平, 王晓方, 王鹤, 祝巍, 胡晓敏, 蔡俊, 赵伟, 赵霞, 郭玉刚, 陶小平, 韦先涛",
                periods: 3,
                startIndex: 11,
                endIndex: 13
            ),
            Lecture(
                startDate: Date().startOfWeek().add(day: 7) + DateComponents(hour: 19, minute: 30),
                endDate: Date().startOfWeek().add(day: 7) + DateComponents(hour: 21, minute: 55),
                name: "大学物理-综合实验 B",
                location: "东区教1楼物理实验室",
                teacherName:
                    "代如成, 刘应玲, 吴玉椿, 孙晓宇, 宋国锋, 岳盈, 张乔枫, 张华洋, 张增明, 张权, 张杨, 曲广媛, 曾华凌, 李恒一, 梁燕, 沈镇, 浦其荣, 王中平, 王晓方, 王鹤, 祝巍, 胡晓敏, 蔡俊, 赵伟, 赵霞, 郭玉刚, 陶小平, 韦先涛",
                periods: 3,
                startIndex: 11,
                endIndex: 13
            ),
        ],
        credit: 1
    )
}

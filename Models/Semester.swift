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
            Course(
                id: 1,
                name: "数学分析 B1",
                courseCode: "MATH1001",
                lessonCode: "MATH1001-01",
                teacherName: "程艺",
                lectures: [
                    Lecture(
                        startDate: Date().stripTime().add(day: 0) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 0) + DateComponents(hour: 9, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 2) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 2) + DateComponents(hour: 11, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 4) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 4) + DateComponents(hour: 9, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 7) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 7) + DateComponents(hour: 9, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 9) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 9) + DateComponents(hour: 11, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 11) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 11) + DateComponents(hour: 9, minute: 50),
                        name: "数学分析 B1",
                        location: "5104",
                        teacherName: "程艺",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                ],
                credit: 6
            ),
            Course(
                id: 2,
                name: "线性代数 A",
                courseCode: "MATH1002",
                lessonCode: "MATH1002-02",
                teacherName: "李尚志",
                lectures: [
                    Lecture(
                        startDate: Date().stripTime().add(day: 1) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 1) + DateComponents(hour: 11, minute: 50),
                        name: "线性代数 A",
                        location: "3207",
                        teacherName: "李尚志",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 3) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 3) + DateComponents(hour: 15, minute: 50),
                        name: "线性代数 A",
                        location: "3207",
                        teacherName: "李尚志",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 8) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 8) + DateComponents(hour: 11, minute: 50),
                        name: "线性代数 A",
                        location: "3207",
                        teacherName: "李尚志",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 10) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 10) + DateComponents(hour: 15, minute: 50),
                        name: "线性代数 A",
                        location: "3207",
                        teacherName: "李尚志",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                ],
                credit: 4
            ),
            Course(
                id: 3,
                name: "大学物理 B1",
                courseCode: "PHYS1001",
                lessonCode: "PHYS1001-03",
                teacherName: "张增明",
                lectures: [
                    Lecture(
                        startDate: Date().stripTime().add(day: 0) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 0) + DateComponents(hour: 15, minute: 50),
                        name: "大学物理 B1",
                        location: "2101",
                        teacherName: "张增明",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 2) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 2) + DateComponents(hour: 15, minute: 50),
                        name: "大学物理 B1",
                        location: "2101",
                        teacherName: "张增明",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 7) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 7) + DateComponents(hour: 15, minute: 50),
                        name: "大学物理 B1",
                        location: "2101",
                        teacherName: "张增明",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 9) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 9) + DateComponents(hour: 15, minute: 50),
                        name: "大学物理 B1",
                        location: "2101",
                        teacherName: "张增明",
                        periods: 2,
                        startIndex: 6,
                        endIndex: 7
                    ),
                ],
                credit: 4
            ),
            Course(
                id: 4,
                name: "程序设计 II",
                courseCode: "CS1002",
                lessonCode: "CS1002-01",
                teacherName: "陈恩红",
                lectures: [
                    Lecture(
                        startDate: Date().stripTime().add(day: 1) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 1) + DateComponents(hour: 9, minute: 50),
                        name: "程序设计 II",
                        location: "科技楼A401",
                        teacherName: "陈恩红",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 4) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 4) + DateComponents(hour: 16, minute: 50),
                        name: "程序设计 II (实验)",
                        location: "西区实验中心2楼",
                        teacherName: "陈恩红",
                        periods: 3,
                        startIndex: 6,
                        endIndex: 8
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 8) + DateComponents(hour: 8, minute: 0),
                        endDate: Date().stripTime().add(day: 8) + DateComponents(hour: 9, minute: 50),
                        name: "程序设计 II",
                        location: "科技楼A401",
                        teacherName: "陈恩红",
                        periods: 2,
                        startIndex: 1,
                        endIndex: 2
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 11) + DateComponents(hour: 14, minute: 0),
                        endDate: Date().stripTime().add(day: 11) + DateComponents(hour: 16, minute: 50),
                        name: "程序设计 II (实验)",
                        location: "西区实验中心2楼",
                        teacherName: "陈恩红",
                        periods: 3,
                        startIndex: 6,
                        endIndex: 8
                    ),
                ],
                credit: 3
            ),
            Course(
                id: 5,
                name: "英语写作",
                courseCode: "ENGL1001",
                lessonCode: "ENGL1001-05",
                teacherName: "王晓红",
                lectures: [
                    Lecture(
                        startDate: Date().stripTime().add(day: 3) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 3) + DateComponents(hour: 11, minute: 50),
                        name: "英语写作",
                        location: "人文楼201",
                        teacherName: "王晓红",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                    Lecture(
                        startDate: Date().stripTime().add(day: 10) + DateComponents(hour: 10, minute: 0),
                        endDate: Date().stripTime().add(day: 10) + DateComponents(hour: 11, minute: 50),
                        name: "英语写作",
                        location: "人文楼201",
                        teacherName: "王晓红",
                        periods: 2,
                        startIndex: 3,
                        endIndex: 4
                    ),
                ],
                credit: 2
            ),
        ],
        name: "2025 秋季学期",
        startDate: Date().stripTime().add(day: -5),
        endDate: Date().stripTime().add(day: 120)
    )
}

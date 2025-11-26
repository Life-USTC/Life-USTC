//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftUI

struct Exam: Codable, Identifiable, Equatable {
    var id = UUID()
    // MARK: - Information about the course

    /// Code to indicate which exact lesson the student is tanking, like MATH1000.01
    /// - Description:
    /// Make sure this is indentical in Score & Course.
    var lessonCode: String
    var courseName: String

    // MARK: - Information about the exam

    /// - Important:
    /// Shown on UI, please set a length limit
    /// - Description:
    /// Some notations are localized, such as 期末考试 <=> Final, 期中考试 <=> Mid-term, 小测 <=> Quiz
    var typeName: String

    var startDate: Date
    var endDate: Date
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String
}

// Provide a richer default array example for [Exam] while avoiding symbol collision.
extension Exam: ExampleArrayDataProtocol, ExampleDataProtocol {
    static let examples: [Exam] = [
        .init(
            lessonCode: "MATH10001.01",
            courseName: "数学分析 B1",
            typeName: "期末考试",
            startDate: Date().stripTime() + DateComponents(day: -1, hour: 14, minute: 0),
            endDate: Date().stripTime() + DateComponents(day: -1, hour: 16, minute: 30),
            classRoomName: "5401",
            classRoomBuildingName: "第五教学楼",
            classRoomDistrict: "东区",
            description: ""
        ),
        .init(
            lessonCode: "PHYS1000.02",
            courseName: "大学物理 B1",
            typeName: "期中考试",
            startDate: Date().stripTime() + DateComponents(day: 7, hour: 9, minute: 0),
            endDate: Date().stripTime() + DateComponents(day: 7, hour: 11, minute: 0),
            classRoomName: "3203",
            classRoomBuildingName: "第三教学楼",
            classRoomDistrict: "西区",
            description: "注意携带计算器"
        ),
    ]
}

typealias ExamDelegateProtocol = ManagedRemoteUpdateProtocol<[Exam]>

extension ManagedDataSource<[Exam]> {
    static let exam = ManagedDataSource(
        local: ManagedLocalStorage("Exam"),
        remote: sharedSchoolExport.examDelegate
    )
}

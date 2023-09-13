//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftUI

struct Exam: Codable, Identifiable, Equatable, ExampleDataProtocol {
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

    static let example: Exam = .init(
        lessonCode: "MATH10001.01",
        courseName: "数学分析B1",
        typeName: "期末考试",
        startDate: Date().stripTime() + DateComponents(hour: 14, minute: 0),
        endDate: Date().stripTime() + DateComponents(hour: 16, minute: 30),
        classRoomName: "5401",
        classRoomBuildingName: "第五教学楼",
        classRoomDistrict: "东区",
        description: ""
    )
}

typealias ExamDelegateProtocol = ManagedRemoteUpdateProtocol<[Exam]>

extension ManagedDataSource<[Exam]> {
    static let exam = ManagedDataSource(
        local: ManagedLocalStorage("Exam"),
        remote: SchoolExport.shared.examDelegate
    )
}

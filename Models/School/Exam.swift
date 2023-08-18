//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftSoup
import SwiftUI
import WidgetKit

struct Exam: Codable, Equatable {
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

    static let example: Exam = .init(lessonCode: "MATH10001.01",
                                     courseName: "数学分析B1",
                                     typeName: "期末考试",
                                     startDate: Date(),
                                     endDate: Date() + DateComponents(hour: 1),
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")
}

extension Exam {
    var detailString: String {
        "\(startDate.description(with: .current)) - \(endDate.description(with: .current)) @ \(classRoomName)"
    }

    static func clean(_ exams: [Exam]) -> [Exam] {
        let hiddenExamName = ([String].init(rawValue: UserDefaults.appGroup.string(forKey: "hiddenExamName") ?? "") ?? []).filter { !$0.isEmpty }
        let result = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return false
                }
            }
            return true
        }
        let hiddenResult = exams.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return true
                }
            }
            return false
        }
        return Exam.show(result) + Exam.show(hiddenResult)
    }
}

protocol ExamDelegateProtocol {
    func refresh() async throws -> [Exam]
}

extension ManagedDataSource {
    static let exam = ManagedUserDefaults(key: "exam", refreshFunc: Exam.sharedDelegate.refresh)
}

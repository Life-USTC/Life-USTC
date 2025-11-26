//
//  Homework.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation

struct Homework: Codable, Identifiable, Equatable {
    var id = UUID()

    var title: String
    var courseName: String

    var dueDate: Date
}

extension Homework {
    var isFinished: Bool {
        Date() > dueDate
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day!
    }
}

extension Homework: ExampleArrayDataProtocol, ExampleDataProtocol {
    static let examples: [Homework] = [
        .init(
            title: "第一次作业",
            courseName: "数学分析 B1",
            dueDate: .now
        )
    ]
}

typealias HomeworkDelegateProtocol = ManagedRemoteUpdateProtocol<[Homework]>

extension ManagedDataSource where D == [Homework] {
    static let homework = ManagedDataSource(
        local: ManagedLocalStorage("Homework"),
        remote: sharedSchoolExport.homeworkDelegate
    )
}

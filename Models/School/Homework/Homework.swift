//
//  Homework.swift
//  学在科大
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation

struct Homework: Codable, Identifiable, Equatable, ExampleDataProtocol {
    var id = UUID()
    
    var title: String
    var courseName: String
    
    var dueDate: Date
    
    static let example: Homework = .init(
        title: "第一次作业",
        courseName: "数学分析B1",
        dueDate: .now
    )
}

typealias HomeworkDelegateProtocol = ManagedRemoteUpdateProtocol<[Homework]>

extension ManagedDataSource<[Homework]> {
    static let homework = ManagedDataSource(
        local: ManagedLocalStorage("Homework"),
        remote: SchoolExport.shared.homeworkDelegate
    )
}

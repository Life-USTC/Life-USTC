//
//  Homework.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation
import SwiftData

@Model
final class Homework {
    var title: String
    var courseName: String
    var dueDate: Date

    var isFinished: Bool {
        Date() > dueDate
    }

    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }

    init(
        title: String,
        courseName: String,
        dueDate: Date
    ) {
        self.title = title
        self.courseName = courseName
        self.dueDate = dueDate
    }
}

extension Homework {
    static let example = Homework(
        title: "Example Assignment",
        courseName: "Example Course",
        dueDate: Date().addingTimeInterval(2 * 24 * 3600)
    )
}

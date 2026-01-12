//
//  Homework.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Homework {
    var title: String
    var courseName: String
    var dueDate: Date

    var color: Color {
        Color.fromSeed(courseName)
    }

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

extension Homework: Comparable {
    static func < (lhs: Homework, rhs: Homework) -> Bool {
        lhs.dueDate < rhs.dueDate
    }
}

extension Homework {
    static func update() async throws {
        try await SchoolSystem.current.updateHomework()
    }
}

extension [Homework] {
    /// Sorts homework so that unfinished ones appear first (chronological).
    /// If showFinishedHomework is true, finished ones appear last (reverse chronological).
    func staged(showFinishedHomework: Bool = true) -> [Homework] {
        let unfinished = self.filter { !$0.isFinished }.sorted()
        if showFinishedHomework {
            return unfinished + self.filter(\.isFinished).sorted().reversed()
        }
        return unfinished
    }
}

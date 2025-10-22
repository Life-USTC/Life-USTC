//
//  ExamExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import EventKit
import Foundation
import SwiftUI

extension Exam {
    /// Full location string combining district, building, and room
    var detailLocation: String {
        "\(classRoomDistrict) \(classRoomBuildingName) \(classRoomName)"
    }

    /// Returns true if the exam end time has passed
    var isFinished: Bool { endDate <= Date() }

    /// Number of days until the exam starts (can be negative if in the past)
    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: .now, to: startDate).day
            ?? 0
    }
}

extension [Exam] {
    /// Returns cleaned exam list with hidden exams moved to the end
    /// Uses AppStorage to track which exam names should be hidden
    /// - Returns: Array with visible exams first, hidden exams last
    func clean() -> [Exam] {
        @AppStorage("hiddenExamName", store: .appGroup) var hiddenExamName: [String] = []
        hiddenExamName = hiddenExamName.filter { !$0.isEmpty }
        var result = self.sorted()
        var hiddenResult = [Exam]()
        for name in hiddenExamName {
            hiddenResult += result.filter { exam in
                exam.courseName.contains(name)
            }

            result.removeAll { exam in
                exam.courseName.contains(name)
            }
        }

        return result + hiddenResult
    }

    /// Sorts exams by start date with unfinished exams first
    /// Unfinished exams sorted ascending, finished exams sorted descending
    /// - Returns: Sorted array with upcoming exams first
    func sorted() -> [Exam] {
        self
            .filter { !$0.isFinished }
            .sorted { $0.startDate < $1.endDate }
            + self
            .filter(\.isFinished)
            .sorted { $0.startDate > $1.endDate }
    }

    /// Merges two exam lists, adding only new exams
    /// - Parameter exams: Exams to merge in
    /// - Returns: Combined array without duplicates
    func merge(with exams: [Exam]) -> [Exam] {
        var result = self
        for exam in exams {
            if !result.filter({ $0 == exam }).isEmpty { continue }
            result.append(exam)
        }
        return result
    }
}

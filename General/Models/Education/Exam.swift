//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftData
import SwiftUI

@Model
final class Exam {
    var lessonCode: String
    var courseName: String

    var typeName: String
    var startDate: Date
    var endDate: Date
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var detailText: String

    var color: Color {
        Color.fromSeed(courseName)
    }

    init(
        lessonCode: String,
        courseName: String,
        typeName: String,
        startDate: Date,
        endDate: Date,
        classRoomName: String,
        classRoomBuildingName: String,
        classRoomDistrict: String,
        description: String
    ) {
        self.lessonCode = lessonCode
        self.courseName = courseName
        self.typeName = typeName
        self.startDate = startDate
        self.endDate = endDate
        self.classRoomName = classRoomName
        self.classRoomBuildingName = classRoomBuildingName
        self.classRoomDistrict = classRoomDistrict
        self.detailText = description
    }
}

extension Exam: Comparable {
    static func < (lhs: Exam, rhs: Exam) -> Bool {
        lhs.startDate < rhs.startDate
    }
}

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
    /// Sorts exams so that unfinished ones appear first (chronological).
    /// If showFinishedExams is true, finished ones appear last (reverse chronological).
    private func _staged(showFinishedExams: Bool = true) -> [Exam] {
        let unfinished = self.filter { !$0.isFinished }.sorted()
        if showFinishedExams {
            return unfinished + self.filter(\.isFinished).sorted().reversed()
        }
        return unfinished
    }

    /// Moves hidden exams to the end of the list based on user preferences while maintaining the staged order
    func staged(showFinishedExams: Bool = true) -> [Exam] {
        @AppStorage("hiddenExamName", store: .appGroup) var hiddenExamName: [String] = []

        let hiddenPatterns = hiddenExamName.filter { !$0.isEmpty }
        var result = self._staged(showFinishedExams: showFinishedExams)
        var hiddenExams = [Exam]()

        for pattern in hiddenPatterns {
            hiddenExams += result.filter { $0.courseName.contains(pattern) }
            result.removeAll { $0.courseName.contains(pattern) }
        }

        return result + hiddenExams
    }
}

extension Exam {
    static func update() async throws {
        try await SchoolSystem.current.updateExam()
    }
}

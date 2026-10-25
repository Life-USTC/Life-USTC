//
//  USTCExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation

extension USTCSchool {
    @MainActor
    static func updateExam() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        // Prefer server data when authenticated
        if ServerClient.shared.isAuthenticated {
            AppLogger.logger(for: "USTCExam").info("Using server for exam update")
            try await ServerDataProvider.updateExams()
            return
        }

        // Fall back to legacy USTC scraping
        AppLogger.logger(for: "USTCExam").info("Using USTC scraping for exam update")
        try await updateExamFromUSTC()
    }

    @MainActor
    static func updateExamFromUSTC() async throws {
        func parseDate(from: String) -> (startTime: Date, endTime: Date)? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            guard let baseDate = dateFormatter.date(from: String(from.prefix(10))) else { return nil }

            let times = String(from.suffix(11)).matches(of: try! Regex("[0-9]+"))
                .map { Double($0.0)! }

            if times.count != 4 { return nil }

            let startTime = baseDate.addingTimeInterval(
                times[0] * 60 * 60 + times[1] * 60
            )
            let endTime = baseDate.addingTimeInterval(
                times[2] * 60 * 60 + times[3] * 60
            )

            return (startTime, endTime)
        }

        @LoginClient(.ustcAAS) var ustcAASClient: USTCAASClient

        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let exams = try await USTCAASService().fetchExams()
        for examData in exams {
            guard let parsed = parseDate(from: examData.dateTime) else {
                continue
            }

            let lessonCode = examData.lessonCode
            let courseName = examData.courseName
            let typeName = examData.examType

            try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<Exam> {
                    $0.lessonCode == lessonCode && $0.courseName == courseName && $0.typeName == typeName
                },
                update: { exam in
                    exam.startDate = parsed.startTime
                    exam.endDate = parsed.endTime
                    exam.classRoomName = examData.roomName
                    exam.classRoomBuildingName = examData.buildingName
                    exam.classRoomDistrict = examData.district
                    exam.detailText = examData.detail
                },
                create: {
                    Exam(
                        lessonCode: lessonCode,
                        courseName: courseName,
                        typeName: typeName,
                        startDate: parsed.startTime,
                        endDate: parsed.endTime,
                        classRoomName: examData.roomName,
                        classRoomBuildingName: examData.buildingName,
                        classRoomDistrict: examData.district,
                        description: examData.detail
                    )
                }
            )
        }
    }
}

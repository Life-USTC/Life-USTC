//
//  USTCExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftSoup

extension USTCSchool {
    @MainActor
    static func updateExam() async throws {
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

        let examURL = URL(
            string: "https://jw.ustc.edu.cn/for-std/exam-arrange"
        )!
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let (data, _) = try await URLSession.shared.data(from: examURL)

        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "")
            )
        }

        let document: Document = try SwiftSoup.parse(dataString)
        let examsParsed: Elements = try document.select("#exams > tbody > tr")

        for examParsed: Element in examsParsed.array() {
            let textList: [String] = examParsed.children().array()
                .map { $0.ownText() }

            guard let parsed = parseDate(from: textList[3]) else {
                continue
            }

            let lessonCode = textList[0]
            let courseName = textList[2]
            let typeName = textList[1]

            try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<Exam> {
                    $0.lessonCode == lessonCode && $0.courseName == courseName && $0.typeName == typeName
                },
                update: { exam in
                    exam.startDate = parsed.startTime
                    exam.endDate = parsed.endTime
                    exam.classRoomName = textList[4]
                    exam.classRoomBuildingName = textList[5]
                    exam.classRoomDistrict = textList[6]
                    exam.detailText = textList[7]
                },
                create: {
                    Exam(
                        lessonCode: lessonCode,
                        courseName: courseName,
                        typeName: typeName,
                        startDate: parsed.startTime,
                        endDate: parsed.endTime,
                        classRoomName: textList[4],
                        classRoomBuildingName: textList[5],
                        classRoomDistrict: textList[6],
                        description: textList[7]
                    )
                }
            )
        }
    }
}

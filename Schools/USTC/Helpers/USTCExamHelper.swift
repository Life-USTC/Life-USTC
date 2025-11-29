//
//  USTCExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftSoup

extension USTCSchool {
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

        @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

        let examURL = URL(
            string: "https://jw.ustc.edu.cn/for-std/exam-arrange"
        )!
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        var request = URLRequest(url: examURL)
        let (data, _) = try await URLSession.shared.data(for: request)

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

            let exam = Exam(
                lessonCode: textList[0],
                courseName: textList[2],
                typeName: textList[1],
                startDate: parsed.startTime,
                endDate: parsed.endTime,
                classRoomName: textList[4],
                classRoomBuildingName: textList[5],
                classRoomDistrict: textList[6],
                description: textList[7]
            )

            SwiftDataStack.modelContext.insert(exam)
        }
    }
}

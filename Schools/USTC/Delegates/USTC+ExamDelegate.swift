//
//  USTCExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftSoup

class USTCExamDelegate: ManagedRemoteUpdateProtocol<[Exam]> {
    static let shared = USTCExamDelegate()

    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    override func refresh() async throws -> [Exam] {
        let examURL = URL(
            string: "https://jw.ustc.edu.cn/for-std/exam-arrange"
        )!
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        var request = URLRequest(url: examURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "")
            )
        }

        let document: Document = try SwiftSoup.parse(dataString)
        let examsParsed: Elements = try document.select("#exams > tbody > tr")
        var result: [Exam] = []

        for examParsed: Element in examsParsed.array() {
            let textList: [String] = examParsed.children().array()
                .map { $0.ownText() }
            if let parsed = parse(rawTime: textList[3]) {
                result.append(
                    Exam(
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
                )
            }
        }
        return result
    }
}

private func parse(rawTime: String) -> (startTime: Date, endTime: Date)? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let baseDate = dateFormatter.date(from: String(rawTime.prefix(10)))
    else { return nil }

    let times = String(rawTime.suffix(11)).matches(of: try! Regex("[0-9]+"))
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

//
//  USTCExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import EventKit
import SwiftSoup
import SwiftUI
import WidgetKit

final class USTCExamDelegate: ExamDelegateProtocol {
    static var shared = USTCExamDelegate()

    func refresh() async throws -> [Exam] {
        if try await !LoginClients.ustcUgAAS.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/exam-arrange")!)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        let document: Document = try SwiftSoup.parse(dataString)
        let examsParsed: Elements = try document.select("#exams > tbody > tr")
        var result: [Exam] = []

        for examParsed: Element in examsParsed.array() {
            let textList: [String] = examParsed.children().array().map { $0.ownText() }
            if let parsed = parse(rawTime: textList[3]) {
                result.append(Exam(lessonCode: textList[0],
                                   courseName: textList[2],
                                   typeName: textList[1],
                                   startDate: parsed.startTime,
                                   endDate: parsed.endTime,
                                   classRoomName: textList[4],
                                   classRoomBuildingName: textList[5],
                                   classRoomDistrict: textList[6],
                                   description: textList[7]))
            }
        }
        return result
    }
}

private func parse(rawTime: String) -> (time: Date, description: String, startTime: Date, endTime: Date)? {
    let dateString = String(rawTime.prefix(10))
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let result = dateFormatter.date(from: dateString) else {
        return nil
    }
    let times = String(rawTime.suffix(11)).matches(of: try! Regex("[0-9]+")).map { Int($0.0)! }
    if times.count != 4 {
        return nil
    }
    let startTime = result.addingTimeInterval(TimeInterval(times[0] * 60 * 60 + times[1] * 60))
    let endTime = result.addingTimeInterval(TimeInterval(times[2] * 60 * 60 + times[3] * 60))
    return (result.stripTime(), String(rawTime.suffix(11)), startTime, endTime)
}

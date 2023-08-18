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
            result.append(Exam(lessonCode: textList[0],
                               courseName: textList[2],
                               typeName: textList[1],
                               rawTime: textList[3],
                               classRoomName: textList[4],
                               classRoomBuildingName: textList[5],
                               classRoomDistrict: textList[6],
                               description: textList[7]))
        }
        return result
    }
}

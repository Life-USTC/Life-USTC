//
//  ExamDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import EventKit
import SwiftSoup
import SwiftUI
import WidgetKit

class ExamDelegate: BaseAsyncDataDelegate {
    typealias D = [Exam]

    var lastUpdate: Date?
    var timeInterval: Double?
    var cacheName: String = "UstcUgAASExamCache"
    var timeCacheName: String = "UstcUgAASLastUpdateExams"
    var ustcUgAASClient: UstcUgAASClient
    var cache: [Exam] = []
    static var shared = ExamDelegate(.shared)

    func parseCache() async throws -> [Exam] {
        let hiddenExamName = (
            [String].init(rawValue: userDefaults.string(forKey: "hiddenExamName") ?? ""
            ) ?? []).filter {
            !$0.isEmpty
        }
        let result = cache.filter { exam in
            for name in hiddenExamName {
                if exam.className.contains(name) {
                    return false
                }
            }
            return true
        }
        let hiddenResult = cache.filter { exam in
            for name in hiddenExamName {
                if exam.className.contains(name) {
                    return true
                }
            }
            return false
        }
        return Exam.show(result) + Exam.show(hiddenResult)
    }

    func forceUpdate() async throws {
        if try await !ustcUgAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/for-std/exam-arrange")!)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        let document: Document = try SwiftSoup.parse(dataString)
        let examsParsed: Elements = try document.select("#exams > tbody > tr")
        var fetchedExams: [Exam] = []

        for examParsed: Element in examsParsed.array() {
            let textList: [String] = examParsed.children().array().map { $0.ownText() }
            fetchedExams.append(Exam(classIDString: textList[0],
                                     typeName: textList[1],
                                     className: textList[2],
                                     rawTime: textList[3],
                                     classRoomName: textList[4],
                                     classRoomBuildingName: textList[5],
                                     classRoomDistrict: textList[6],
                                     description: textList[7]))
        }

        lastUpdate = Date()
        cache = fetchedExams
        WidgetCenter.shared.reloadAllTimelines()
        try saveCache()
    }

    init(_ client: UstcUgAASClient) {
        ustcUgAASClient = client
        exceptionCall {
            try self.loadCache()
        }
    }
}

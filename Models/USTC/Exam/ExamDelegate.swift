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

class ExamDelegate: UserDefaultsADD & LastUpdateADD {
    // Protocol requirements
    typealias D = [Exam]
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASExamCache"
    var timeCacheName: String = "UstcUgAASLastUpdateExams"
    var status: AsyncViewStatus = .inProgress {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    // Parent
    var ustcUgAASClient: UstcUgAASClient

    // Shared class that shall be used throughout the app
    // You should call function with ExamDelegate.shared.function()
    // instead of ExamDelegate().function()
    // The benifit of this, instead of just using enum for definition
    // is that the lifecycle could be easily managed and checked when debugging.
    //
    // Notice that all ExamDelegate() share the same cache,
    // and there aren't supposed to be two instance running at the same time to avoid conflict
    // TODO: Add support for multiple instance with different cache position
    static var shared = ExamDelegate()

    var cache: [Exam] = []
    var data: [Exam] = [] {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

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
        cache = fetchedExams

        try await afterForceUpdate()
        WidgetCenter.shared.reloadAllTimelines()
    }

    init(_ client: UstcUgAASClient = .shared) {
        ustcUgAASClient = client

        afterInit()
    }
}

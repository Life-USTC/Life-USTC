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

    // MARK: - Protocol requirements

    typealias D = [Exam]
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASExamCache"
    var timeCacheName: String = "UstcUgAASLastUpdateExams"
    @Published var status: AsyncViewStatus = .inProgress
    var cache: [Exam] = []
    @Published var data: [Exam] = []
    var placeHolderData: [Exam] = [.example]

    // MARK: - Start reading from here:

    func parseCache() async throws -> [Exam] {
        let hiddenExamName = (
            [String].init(rawValue: UserDefaults.appGroup.string(forKey: "hiddenExamName") ?? ""
            ) ?? []).filter {
            !$0.isEmpty
        }
        let result = cache.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return false
                }
            }
            return true
        }
        let hiddenResult = cache.filter { exam in
            for name in hiddenExamName {
                if exam.courseName.contains(name) {
                    return true
                }
            }
            return false
        }
        return Exam.show(result) + Exam.show(hiddenResult)
    }

    func refreshCache() async throws {
        if try await !LoginClients.ustcUgAAS.requireLogin() {
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
            fetchedExams.append(Exam(lessonCode: textList[0],
                                     typeName: textList[1],
                                     courseName: textList[2],
                                     rawTime: textList[3],
                                     classRoomName: textList[4],
                                     classRoomBuildingName: textList[5],
                                     classRoomDistrict: textList[6],
                                     description: textList[7]))
        }
        cache = fetchedExams

        try await afterForceUpdate()
    }

    init() {
        afterInit()
    }
}

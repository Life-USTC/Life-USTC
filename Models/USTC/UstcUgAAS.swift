//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import SwiftSoup
import SwiftUI
import SwiftyJSON
import WidgetKit

/// USTC Undergraduate Academic Affairs System
enum UstcUgAASClient {
    private static var lastLogined: Date?
    private static var semesterID: String = userDefaults.string(forKey: "semesterID") ?? "301"

    static var curriculumDelegate = CurriculumDelegate()
    static var examDelegate = ExamDelegate()
    static var scoreDelegate = ScoreDelegate()

    private static func login() async throws -> Bool {
        if try await !UstcCasClient.requireLogin() {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        // jw.ustc.edu.cn login.
        let session = URLSession.shared
        let _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())

        if session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "SESSION" }) ?? false {
            lastLogined = .now
            return true
        }
        return false
    }

    static func checkLogined() async throws -> Bool {
        if lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 15) {
            return false
        }
        let session = URLSession.shared
        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "fine_auth_token" }) ?? false
    }

    static func requireLogin() async throws -> Bool {
        if try await checkLogined() {
            return true
        } else {
            return try await login()
        }
    }
}

extension UstcUgAASClient {
    // TODO: Maintain a list of these values online, use cached to store them on device
    static let semesterIDList: [String: String] =
        ["2021年秋季学期": "221",
         "2022年春季学期": "241",
         "2022年夏季学期": "261",
         "2022年秋季学期": "281",
         "2023年春季学期": "301"]
    static let semesterDateList: [String: Date] =
        ["2021年秋季学期": .init(timeIntervalSince1970: 1_630_771_200),
         "2022年春季学期": .init(timeIntervalSince1970: 1_642_608_000),
         "2022年夏季学期": .init(timeIntervalSince1970: 1_656_172_800),
         "2022年秋季学期": .init(timeIntervalSince1970: 1_661_616_000),
         "2023年春季学期": .init(timeIntervalSince1970: 1_677_945_600)]

    static func selectSemester(id: String) {
        semesterID = id
    }

    static func getSemesterID() -> String {
        semesterID
    }

    static var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })!.key
    }

    static var semesterStartDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterName })!.value
    }
}

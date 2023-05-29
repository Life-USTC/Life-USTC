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
actor UstcUgAASClient {
    static var shared = UstcUgAASClient(session: .shared)

    var session: URLSession
    var semesterID: String {
        userDefaults.string(forKey: "semesterID") ?? "301"
    }

    var lastLogined: Date?

    init(session: URLSession) {
        self.session = session
    }

    private func login() async throws -> Bool {
        print("network:UstcUgAAS login called")
        if try await !UstcCasClient.shared.requireLogin() {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        // jw.ustc.edu.cn login.
        let _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())

//        if session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "SESSION" }) ?? false {
//            lastLogined = .now
//            return true
//        }
//        return false
        debugPrint(session.configuration.httpCookieStorage?.cookies)
        lastLogined = .now
        return true
    }

    func checkLogined() -> Bool {
        if lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 15) {
            return false
        }
        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "fine_auth_token" }) ?? false
    }

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            return try await loginTask.value
        }

        if checkLogined() {
            return true
        }

        let task = Task {
            let result = try await self.login()
            loginTask = nil
            return result
        }
        loginTask = task
        return try await task.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }

    func weekNumber(for date: Date = Date()) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents([.weekOfYear], from: date).weekOfYear! - calendar.dateComponents([.weekOfYear], from: semesterStartDate).weekOfYear! + 1
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

    var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })!.key
    }

    var semesterStartDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterName })!.value
    }
}

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
class UstcUgAASClient: ObservableObject {
    static var shared = UstcUgAASClient()

    var session: URLSession = .shared
    var semesterID: Int {
        userDefaults.integer(forKey: "semesterIDInt")
    }

    var lastLogined: Date? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    func login() async throws -> Bool {
        let UgAASCASLoginURL = URL(string: "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin")!
        print("network<UstcUgAAS>: login called")

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!)

        // handle CAS with casClient
        let tmpCASSession = UstcCasClient(session: session)
        _ = try await tmpCASSession.loginToCAS(url: UgAASCASLoginURL)

        // now try login url, see if that directs to home page
        var request = URLRequest(url: UgAASCASLoginURL)
        request.httpMethod = "GET"
        let (_, response) = try await session.data(for: request)

        print("network<UstcUgAAS>: Login finished, Cookies:")

        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
            print("[\(cookie.domain)]\tNAME:\(cookie.name)\tVALUE:\(cookie.value)")
        }

        let result = (response.url == URL(string: "https://jw.ustc.edu.cn/home")!)
        if result {
            lastLogined = .now
        }

        return result
    }

    func checkLogined() -> Bool {
        if lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 5) {
            print("network<UstcUgAAS>: Not logged in, [REQUIRE LOGIN]")
            return false
        }
        print("network<UstcUgAAS>: Already logged in, passing")
        return true
    }

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            print("network<UstcUgAAS>: login task already running, [WAITING RESULT]")
            return try await loginTask.value
        }

        if checkLogined() {
            return true
        }

        let task = Task {
            print("network<UstcUgAAS>: No login task running, [CREATING NEW ONE]")
            let result = try await self.login()
            loginTask = nil
            print("network<UstcUgAAS>: login task finished, result:\(result)")
            return result
        }
        loginTask = task
        return try await task.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }
}

extension UstcUgAASClient {
    // TODO: Maintain a list of these values online, use cached to store them on device
    static let semesterIDList: [Int: String] =
        [221: "2021年秋季学期",
         241: "2022年春季学期",
         261: "2022年夏季学期",
         281: "2022年秋季学期",
         301: "2023年春季学期"]
    static let semesterDateList: [Int: Date] =
        [221: .init(timeIntervalSince1970: 1_630_771_200),
         241: .init(timeIntervalSince1970: 1_642_608_000),
         261: .init(timeIntervalSince1970: 1_656_172_800),
         281: .init(timeIntervalSince1970: 1_661_616_000),
         301: .init(timeIntervalSince1970: 1_677_945_600)]

    var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.key == semesterID })?.value ?? "Not Found"
    }

    var semesterStartDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterID })?.value ?? Date()
    }

    // TODO: NOT DONE YET
    var semesterEndDate: Date {
        semesterStartDate
    }

    var semesterWeeks: Int {
        10
    }
}

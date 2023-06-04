//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation
import os

let findLtStringRegex = try! Regex("LT-[0-9a-z]+")

extension URL {
    /// Mark self for the CAS service to identify as a service
    ///
    ///  - Parameters:
    ///    - casServer: URL to the CAS server, NOT the service URL(which is URL.self)
    func CASLoginMarkup(casServer: URL) -> URL {
        var components = URLComponents(url: casServer.appendingPathComponent("login"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "service", value: absoluteString)]
        return components.url ?? exampleURL
    }

    func ustcCASLoginMarkup() -> URL {
        CASLoginMarkup(casServer: ustcCasUrl)
    }
}

/// A cas client to login to https://passport.ustc.edu.cn/
actor UstcCasClient {
    static var shared = UstcCasClient(session: .shared)

    var session: URLSession
    var username: String {
        userDefaults.string(forKey: "passportUsername") ?? ""
    }

    var password: String {
        userDefaults.string(forKey: "passportPassword") ?? ""
    }

    var lastLogined: Date?

    init(session: URLSession, lastLogined _: Date? = nil) {
        self.session = session
    }

    var precheckFails: Bool {
        username.isEmpty || password.isEmpty
    }

    func getLtTokenFromCAS(url: URL? = nil) async throws -> (ltToken: String, cookie: [HTTPCookie]) {
        // loading the LT-Token requires a non-logined status, which shared Session could have not provide
        // using a ephemeral session would achieve this.
        let session = URLSession(configuration: .ephemeral)
        let (data, _) = try await session.data(from: url ?? ustcLoginUrl)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        guard let match = dataString.firstMatch(of: findLtStringRegex) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        let ltToken = String(match.0)

        print("network<UstcCAS>: LT-TOKEN GET: \(ltToken)")

        return (ltToken, session.configuration.httpCookieStorage?.cookies ?? [])
    }

    func loginToCAS(url: URL? = nil) async throws -> Bool {
        if precheckFails {
            throw BaseError.runtimeError("network<UstcCAS>: precheck fails")
        }
        print("network<UstcCAS>: login called")

        let (ltToken, cookies) = try await getLtTokenFromCAS(url: url)

        // - For POST request, the query items should be in the body, here'e the correct way to do it
        var components = URLComponents(url: ustcLoginUrl, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "model", value: "uplogin.jsp"),
                                 URLQueryItem(name: "CAS_LT", value: ltToken),
                                 URLQueryItem(name: "service", value: ""),
                                 URLQueryItem(name: "warn", value: ""),
                                 URLQueryItem(name: "showCode", value: ""),
                                 URLQueryItem(name: "qrcode", value: ""),
                                 URLQueryItem(name: "username", value: username),
                                 URLQueryItem(name: "password", value: password),
                                 URLQueryItem(name: "LT", value: ""),
                                 URLQueryItem(name: "button", value: "")]

        var request = URLRequest(url: ustcLoginUrl)
        request.httpBody = components.query?.data(using: .utf8)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = true
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://passport.ustc.edu.cn/login", forHTTPHeaderField: "Referer")
        session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcCasUrl, mainDocumentURL: ustcCasUrl)

        let _ = try await session.data(for: request)

        print("network<UstcCAS>: Login To CAS Finished, Cookies:")

        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
            print("[\(cookie.domain)]\tNAME:\(cookie.name)\tVALUE:\(cookie.value)")
        }

        if session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" }) ?? false {
            lastLogined = .now
            return true
        }
        return false
    }

    @available(*, deprecated)
    func login(undeterimined _: Bool = false) async throws -> Bool {
        try await loginToCAS()
    }

    func checkLogined() -> Bool {
        if precheckFails || lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 5) {
            return false
        }
        let session = URLSession.shared
        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" }) ?? false
    }

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            print("network<UstcCAS>: login task already running, [CREATE NEW ONE]")
            return try await loginTask.value
        }

        if checkLogined() {
            print("network<UstcCAS>: Already logged in, passing")
            return true
        }

        let task = Task {
            print("network<UstcCAS>: No login task running, [CREATING NEW ONE]")
            let result = try await self.loginToCAS()
            loginTask = nil
            print("network<UstcCAS>: login task finished, result: \(result)")
            return result
        }
        loginTask = task
        return try await task.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }
}

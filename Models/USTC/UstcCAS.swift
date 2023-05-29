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

    func getLtTokenFromCAS() async throws -> (ltToken: String, cookie: [HTTPCookie]) {
        // loading the LT-Token requires a non-logined status, which shared Session could have not provide
        // using a ephemeral session would achieve this.
        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(from: ustcLoginUrl)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        guard let match = dataString.firstMatch(of: findLtStringRegex) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        let httpRes: HTTPURLResponse = (response as? HTTPURLResponse)!
        return (String(match.0), HTTPCookie.cookies(withResponseHeaderFields: httpRes.allHeaderFields as! [String: String], for: httpRes.url!))
    }

    private func loginToCAS() async throws -> Bool {
        if precheckFails {
            throw BaseError.runtimeError("precheck fails")
        }
        let session = URLSession.shared
        let (ltToken, cookies) = try await getLtTokenFromCAS()

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

        let (data, response) = try await session.data(for: request)
//        debugPrint(request.url?.absoluteString)
//        debugPrint(String(data: request.httpBody!, encoding: .utf8))
//        debugPrint(String(data: data, encoding: .utf8), response)
//        debugPrint(session.configuration.httpCookieStorage?.cookies)
        if session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" }) ?? false {
            lastLogined = .now
            return true
        }
        return false
    }

    @available(*, deprecated)
    func login(undeterimined _: Bool = false) async throws -> Bool {
        print("network:UstcCAS login called")
//        while true {
//            do {
//                if try await loginToCAS() {
//                    return true
//                }
//            } catch {}
//            if undeterimined {
//                return false
//            }
//            try await Task.sleep(for: .seconds(2))
//        }
        return try await loginToCAS()
    }

    func checkLogined() -> Bool {
        if precheckFails || lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 15) {
            return false
        }
        let session = URLSession.shared
        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" }) ?? false
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
}

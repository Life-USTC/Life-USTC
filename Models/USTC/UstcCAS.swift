//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation

let findLtStringRegex = try! Regex("LT-[0-9a-z]+")

extension URL {
    /// Mark self for the CAS service to identify as a service
    ///
    ///  - Parameters:
    ///    - casServer: URL to the CAS server, NOT the service URL(which is URL.self)
    func CASLoginMarkup(casServer: URL) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "service", value: components.url!.absoluteString)]
        return URL(string: "\(casServer)/login?service=\(components.url!.absoluteString)")!
    }

    func ustcCASLoginMarkup() -> URL {
        CASLoginMarkup(casServer: ustcCasUrl)
    }
}

/// A cas client to login to https://passport.ustc.edu.cn/
enum UstcCasClient {
    static var username: String = userDefaults.string(forKey: "passportUsername") ?? ""
    static var password: String = userDefaults.string(forKey: "passportPassword") ?? ""

    private static var lastLogined: Date?

    private static var precheckFails: Bool {
        username.isEmpty || password.isEmpty
    }

    static func update(username: String, password: String) {
        self.username = username
        self.password = password
    }

    static func getLtTokenFromCAS() async throws -> (ltToken: String, cookie: [HTTPCookie]) {
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

    /// Call this function before using casCookie
    static func loginToCAS() async throws -> Bool {
        if precheckFails {
            return false
        }
        let session = URLSession.shared
        let (ltToken, cookies) = try await getLtTokenFromCAS()

        let dataString = "model=uplogin.jsp&CAS_LT=\(ltToken)&service=&warn=&showCode=&qrcode=&username=\(username)&password=\(password)&LT=&button="
        var request = URLRequest(url: ustcLoginUrl)
        request.httpMethod = "POST"
        request.httpBody = dataString.data(using: .utf8)
        request.httpShouldHandleCookies = true
        session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcCasUrl, mainDocumentURL: ustcCasUrl)

        _ = try await session.data(for: request)
        lastLogined = .now

        return try await checkLogined()
    }

    static func checkLogined() async throws -> Bool {
        if precheckFails || lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 15) {
            return false
        }
        let session = URLSession.shared
        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" }) ?? false
    }

    static func requireLogin() async throws -> Bool {
        if try await checkLogined() {
            return true
        } else {
            return try await loginToCAS()
        }
    }
}

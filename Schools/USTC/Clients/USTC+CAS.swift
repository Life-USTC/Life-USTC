//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation

/// A cas client to login to https://passport.ustc.edu.cn/
class UstcCasClient: LoginClientProtocol {
    static var shared = UstcCasClient()

    var session: URLSession = .shared

    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String

    var precheckFails: Bool {
        username.isEmpty || password.isEmpty
    }

    func getLtTokenFromCAS(url: URL = ustcLoginUrl) async throws -> (ltToken: String, cookie: [HTTPCookie]) {
        let findLtStringRegex = try! Regex("LT-[0-9a-z]+")
        // loading the LT-Token requires a non-logined status, which shared Session could have not provide
        // using a ephemeral session would achieve this.
        let session = URLSession(configuration: .ephemeral)
        let (data, _) = try await session.data(from: url)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw BaseError.runtimeError("network<UstcCAS>: failed to fetch raw LT-Token")
        }

        guard let match = dataString.firstMatch(of: findLtStringRegex) else {
            throw BaseError.runtimeError("network<UstcCAS>: failed to fetch raw LT-Token")
        }

        let ltToken = String(match.0)
        print("network<UstcCAS>: LT-TOKEN GET: \(ltToken)")
        return (ltToken, session.configuration.httpCookieStorage?.cookies ?? [])
    }

    func loginToCAS(url: URL = ustcLoginUrl, service: URL? = nil) async throws -> Bool {
        if precheckFails {
            throw BaseError.runtimeError("network<UstcCAS>: precheck fails")
        }
        print("network<UstcCAS>: login called")

        let (ltToken, cookies) = try await getLtTokenFromCAS(url: url)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "model", value: "uplogin.jsp"),
                                 URLQueryItem(name: "CAS_LT", value: ltToken),
                                 URLQueryItem(name: "service", value: service?.absoluteString ?? ""),
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
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcCasUrl, mainDocumentURL: ustcCasUrl)

        let _ = try await session.data(for: request)

        print("network<UstcCAS>: Login To CAS Finished, Cookies:")

        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
            print("[\(cookie.domain)]\tNAME:\(cookie.name)\tVALUE:\(cookie.value)")
        }

        return session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "logins" || $0.name == "TGC" }) ?? false
    }

    func login() async throws -> Bool {
        try await loginToCAS()
    }

    init() {}
}

extension LoginClients {
    var ustcCAS: UstcCasClient {
        UstcCasClient.shared
    }
}

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

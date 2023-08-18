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
class UstcUgAASClient: LoginClient {
    static var shared = UstcUgAASClient()

    var session: URLSession = .shared

    func login() async throws -> Bool {
        let UgAASCASLoginURL = URL(string: "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin")!
        print("network<UstcUgAAS>: login called")

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!)

        // handle CAS with casClient
        let tmpCASSession = UstcCasClient(session: session)
        _ = try await tmpCASSession.loginToCAS(url: UgAASCASLoginURL, service: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!)

        // now try login url, see if that directs to home page
        var request = URLRequest(url: UgAASCASLoginURL)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        print("network<UstcUgAAS>: Login finished, Cookies:")

        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
            print("[\(cookie.domain)]\tNAME:\(cookie.name)\tVALUE:\(cookie.value)")
        }

        return (response.url == URL(string: "https://jw.ustc.edu.cn/home")!)
    }
}

extension LoginClients {
    static let ustcUgAAS = LoginClientWrapper(UstcUgAASClient.shared)
}

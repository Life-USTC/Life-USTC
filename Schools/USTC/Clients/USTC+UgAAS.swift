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
class UstcUgAASClient: LoginClientProtocol {
    static var shared = UstcUgAASClient()

    var session: URLSession = .shared

    func login() async throws -> Bool {
        let urlA = URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!
        let urlB = URL(string: "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin")!
        let urlC = URL(string: "https://jw.ustc.edu.cn/home")!
        print("network<UstcUgAAS>: login called")

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: urlA)
        _ = try await LoginClients.ustcCAS.wrappedValue.loginToCAS(url: urlB, service: urlA)

        // now try login url, see if that directs to home page
        var request = URLRequest(url: urlB)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        print("network<UstcUgAAS>: Login finished, Cookies:")

        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
            print("[\(cookie.domain)]\tNAME:\(cookie.name)\tVALUE:\(cookie.value)")
        }

        return (response.url == urlC)
    }
}

extension LoginClients {
    static let ustcUgAAS = LoginClient(UstcUgAASClient.shared)
}

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
class UstcAASClient: LoginClientProtocol {
    static let shared = UstcAASClient()

    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {
        if !(try await _casClient.requireLogin()) {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!)
        _ = try await casClient.loginToCAS(URL(
            string:
                "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin"
        )!)

        // now try if we are logined by visiting the home page
        var request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/")!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        return (response.url == URL(string: "https://jw.ustc.edu.cn/home")!)
    }
}

extension LoginClientProtocol {
    static var ustcAAS = UstcAASClient.shared
}

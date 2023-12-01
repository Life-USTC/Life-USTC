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

private let urlA = URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!
private let urlB = URL(
    string:
        "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin"
)!
private let urlC = URL(string: "https://jw.ustc.edu.cn/home")!

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient: LoginClientProtocol {
    static let shared = UstcUgAASClient()

    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: urlA)
        _ = try await casClient.loginToCAS(url: urlB, service: urlA)

        // now try login url, see if that directs to home page
        var request = URLRequest(url: urlB)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        return (response.url == urlC)
    }
}

extension LoginClientProtocol {
    static var ustcUgAAS = UstcUgAASClient.shared
}

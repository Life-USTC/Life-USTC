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
class USTCAASClient: LoginClientProtocol {
    static let shared = USTCAASClient()

    @LoginClient(.ustcCAS) var casClient: USTCCASClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {
        if !(try await _casClient.requireLogin()) {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        _ = try await session.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!)

        _ = try await session.data(
            from: URL(
                string: "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin"
            )!
        )

        let (_, response) = try await session.data(
            from: URL(string: "https://jw.ustc.edu.cn/")!
        )

        return response.url?.absoluteString == "https://jw.ustc.edu.cn/home"
    }
}

extension LoginClientProtocol {
    static var ustcAAS = USTCAASClient.shared
}

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

        return try await USTCAASService(session: session).establishSession()
    }
}

extension LoginClientProtocol {
    static var ustcAAS = USTCAASClient.shared
}

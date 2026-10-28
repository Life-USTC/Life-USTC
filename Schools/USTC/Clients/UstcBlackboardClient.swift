//
//  USTC+Blackboard.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftUI

/// USTC Undergraduate Academic Affairs System
class USTCBlackboardClient: LoginClientProtocol {
    static let shared = USTCBlackboardClient()

    @LoginClient(.ustcCAS) var casClient: USTCCASClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {
        if !(try await _casClient.requireLogin()) {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        return try await USTCBlackboardService(session: session).establishSession()
    }
}

extension LoginClientProtocol {
    static var ustcBlackboard = USTCBlackboardClient.shared
}

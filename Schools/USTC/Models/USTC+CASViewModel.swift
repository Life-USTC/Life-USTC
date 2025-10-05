//
//  USTC+CASViewModel.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

class UstcCasViewModel: ObservableObject {
    static let shared = UstcCasViewModel()

    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String
    @Published public var inputUsername: String = ""
    @Published public var inputPassword: String = ""

    init() {
        inputUsername = username
        inputPassword = password
    }

    func checkAndLogin() async throws -> Bool {
        if inputUsername.isEmpty || inputPassword.isEmpty {
            return false
        }

        if inputUsername == demoUserName && inputPassword == demoPassword {
            appShouldPresentDemo = true
            return true
        }
        appShouldPresentDemo = false

        username = inputUsername
        password = inputPassword

        return try await _casClient.requireLogin()
    }
}

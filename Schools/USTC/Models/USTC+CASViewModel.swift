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
    @AppSecureStorage("passportUsername") var username: String
    @AppSecureStorage("passportPassword") var password: String
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

        _casClient.clearLoginStatus()
        return try await casClient.login(
            shouldAutoLogin: true,
            username: inputUsername,
            password: inputPassword
        )
    }
}

//
//  USTC+CASViewModel.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

class UstcCasViewModel: ObservableObject {
    static let shared = UstcCasViewModel()

    @LoginClient(\.ustcCAS) var casClient: UstcCasClient
    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String
    @Published public var inputUsername: String = ""
    @Published public var inputPassword: String = ""

    init() {
        inputUsername = username
        inputPassword = password
    }

    func checkAndLogin() async throws -> Bool {
        guard !(inputUsername.isEmpty || inputPassword.isEmpty) else {
            return false
        }

        username = inputUsername
        password = inputPassword

        _casClient.clearLoginStatus()
        await URLSession.shared.reset()
        return try await _casClient.requireLogin()
    }
}

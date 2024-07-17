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
    @AppSecureStorage("passportDeviceID") private var deviceID: String
    @AppSecureStorage("passportFingerprint") private var fingerPrint: String
    @Published public var inputUsername: String = ""
    @Published public var inputPassword: String = ""
    @Published public var inputDeviceID: String = ""
    @Published public var inputFingerPrint: String = ""

    init() {
        inputUsername = username
        inputPassword = password
        inputDeviceID = deviceID
        inputFingerPrint = fingerPrint
    }

    func checkAndLogin() async throws -> Bool {
        if (inputUsername.isEmpty || inputPassword.isEmpty || inputDeviceID.isEmpty || inputFingerPrint.isEmpty) {
            return false
        }

        if inputUsername == demoUserName && inputPassword == demoPassword {
            appShouldPresentDemo = true
            return true
        }
        appShouldPresentDemo = false

        username = inputUsername
        password = inputPassword
        deviceID = inputDeviceID
        fingerPrint = inputFingerPrint

        _casClient.clearLoginStatus()
        await URLSession.shared.reset()
        return try await _casClient.requireLogin()
    }
}

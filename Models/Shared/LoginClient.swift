//
//  LoginClient.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

class LoginClientProtocol {
    /// Return True if login success
    func login() async throws -> Bool {
        false
    }
}

@propertyWrapper
class LoginClient<T: LoginClientProtocol> {
    var wrappedValue: T
    var lastLogined: Date?
    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            return try await loginTask.value
        }

        if lastLogined != nil, Date().timeIntervalSince(lastLogined!) < 5 * 60 {
            return true
        }

        loginTask = Task {
            do {
                if try await self.wrappedValue.login() {
                    lastLogined = Date()
                    return true
                }
                loginTask = nil
                return false
            } catch {
                loginTask = nil
                throw (error)
            }
        }
        return try await loginTask!.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }

    init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

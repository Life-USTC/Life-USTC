//
//  LoginClient.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

protocol LoginClientProtocol {
    /// Return True if login success
    func login() async throws -> Bool
}

@propertyWrapper
class LoginClient<T: LoginClientProtocol> {
    var wrappedValue: T

    var lastLogined: Date?

    func checkLogined() -> Bool {
        if lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 5) {
            print("network<\(T.self)>: Not logged in, [REQUIRE LOGIN]")
            return false
        }
        print("network<\(T.self)>: Already logged in, passing")
        return true
    }

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            print("network<\(T.self)>: login task already running, [WAITING RESULT]")
            return try await loginTask.value
        }

        if checkLogined() {
            return true
        }

        let task = Task {
            do {
                print("network<\(T.self)>: No login task running, [CREATING NEW ONE]")
                let result = try await self.wrappedValue.login()
                loginTask = nil
                print("network<\(T.self)>: login task finished, result:\(result)")
                if result {
                    lastLogined = .now
                }
                return result
            } catch {
                loginTask = nil
                throw (error)
            }
        }
        loginTask = task
        return try await task.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }

    init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

enum LoginClients {}

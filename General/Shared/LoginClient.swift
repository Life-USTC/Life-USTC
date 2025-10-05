//
//  LoginClient.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

class LoginClientProtocol {
    /// Return True if login success
    func login() async throws -> Bool {
        assert(true)
        return false
    }
}

@propertyWrapper class LoginClient<T: LoginClientProtocol> {
    var wrappedValue: T

    @AppStorage(
        "\(T.self)_lastLogined",
        store: .appGroup
    ) var lastLogined: Date?

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let lastLogined, Date().timeIntervalSince(lastLogined) < 5 * 60 {
            return true
        }

        // Waiting random time to avoid racing condition
        try await Task.sleep(
            nanoseconds: UInt64.random(in: 0 ..< 1_000_000_000)
        )

        if let loginTask {
            return try await loginTask.value
        }

        loginTask = Task {
            do {
                if try await self.wrappedValue.login() {
                    lastLogined = Date()
                    loginTask = nil
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

extension URL {
    /// Mark self for the CAS service to identify as a service
    ///
    ///  - Parameters:
    ///    - casServer: URL to the CAS server, NOT the service URL(which is URL.self)
    func CASLoginMarkup(casServer: URL) -> URL {
        var components = URLComponents(
            url: casServer.appendingPathComponent("login"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [.init(name: "service", value: absoluteString)]
        return components.url ?? exampleURL
    }
}

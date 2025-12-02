//
//  LoginClient.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation
import SwiftUI

private var loginClientClearedTypeIdentifiers = Set<ObjectIdentifier>()
private let loginClientClearedQueue = DispatchQueue(
    label: "life.ustc.loginclient.clear"
)

class LoginClientProtocol {
    let state = LoginStateActor()

    /// Return True if login success
    func login() async throws -> Bool {
        assert(true)
        throw BaseError.notImplemented
    }
}

@propertyWrapper
class LoginClient<T: LoginClientProtocol> {
    var wrappedValue: T

    @AppStorage(
        "\(T.self)_lastLogined",
        store: .appGroup
    ) private var lastLogined: Date?

    init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
        clearIfNeededOnLaunch()
    }

    func requireLogin() async throws -> Bool {
        return try await wrappedValue.state.requireLogin(
            lastLogined: { self.lastLogined },
            setLastLogined: { self.lastLogined = $0 },
            performLogin: { try await self.wrappedValue.login() }
        )
    }

    func clearLoginStatus() {
        lastLogined = nil
    }

    private func clearIfNeededOnLaunch() {
        let identifier = ObjectIdentifier(T.self)
        var shouldClear = false
        loginClientClearedQueue.sync {
            if !loginClientClearedTypeIdentifiers.contains(identifier) {
                loginClientClearedTypeIdentifiers.insert(identifier)
                shouldClear = true
            }
        }
        if shouldClear {
            lastLogined = nil
        }
    }
}

actor LoginStateActor {
    private var loginTask: Task<Bool, Error>? = nil

    func requireLogin(
        lastLogined: () -> Date?,
        setLastLogined: @escaping (Date?) -> Void,
        performLogin: @escaping () async throws -> Bool
    ) async throws -> Bool {
        // Fresh enough → nothing to do
        if let ts = lastLogined(),
            Date().timeIntervalSince(ts) < 5 * 60
        {
            return true
        }

        // If a login is already going on, wait for it.
        if let task = loginTask {
            return try await task.value
        }

        // Start one login for all callers.
        self.loginTask = Task {
            do {
                let ok = try await performLogin()
                if ok {
                    setLastLogined(Date())
                }
                return ok
            } catch {
                throw error
            }
        }

        defer { loginTask = nil }

        return try await loginTask!.value
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
        return components.url ?? Constants.exampleURL
    }
}

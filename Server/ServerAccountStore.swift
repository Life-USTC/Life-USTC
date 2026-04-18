//
//  ServerAccountStore.swift
//  Life@USTC
//
//  Shared observable state for server authentication and user profile.
//  Used by both the Settings inline account row and ServerAccountView.
//

import AuthenticationServices
import Foundation
import SwiftUI

@Observable
final class ServerAccountStore {
    static let shared = ServerAccountStore()

    private(set) var user: ServerUser?
    private(set) var isLoading = false
    private(set) var error: String?

    var isAuthenticated: Bool {
        ServerClient.shared.isAuthenticated
    }

    var displayName: String {
        user?.name ?? user?.username ?? user?.email ?? "User"
    }

    private init() {}

    @MainActor
    func loadUser() async {
        guard isAuthenticated else {
            user = nil
            return
        }
        isLoading = true
        error = nil
        do {
            user = try await ServerClient.shared.fetchCurrentUser()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func login() async {
        isLoading = true
        error = nil
        do {
            try await ServerAuth.shared.login()
            await loadUser()
        } catch {
            if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    func logout() {
        ServerAuth.shared.logout()
        user = nil
        error = nil
    }

    /// Called when backend URL changes — reset all state.
    func onBackendChanged() {
        user = nil
        error = nil
        isLoading = false
    }
}

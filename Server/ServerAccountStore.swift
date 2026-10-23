//
//  ServerAccountStore.swift
//  Life@USTC
//
//  Shared observable state for server authentication and user profile.
//  Used by both the Settings inline account row and ServerAccountView.
//

import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

@Observable
final class ServerAccountStore {
    static let shared = ServerAccountStore()

    private(set) var user: ServerUser?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var sessionRevision = UUID()
    private(set) var learningSyncError: String?
    private let client: ServerClient
    private let learningContext: ModelContext?
    private let isPresentingDemo: () -> Bool
    private var observedClientRevision: UUID?

    var isAuthenticated: Bool {
        client.isAuthenticated
    }

    var displayName: String {
        user?.name ?? user?.username ?? user?.email ?? "User"
    }

    init(
        client: ServerClient = .shared,
        learningContext: ModelContext? = nil,
        isPresentingDemo: @escaping () -> Bool = { SwiftDataStack.isPresentingDemo }
    ) {
        self.client = client
        self.learningContext = learningContext
        self.isPresentingDemo = isPresentingDemo
        // A signed-out cold start must remove any former owner's disk cache.
        // An existing signed-in session keeps its snapshot available offline.
        observedClientRevision = client.isAuthenticated ? client.sessionRevision : nil
    }

    @MainActor
    func loadUser() async {
        onSessionChanged()
        let expectedRevision = client.sessionRevision
        guard isAuthenticated else {
            user = nil
            return
        }
        isLoading = true
        error = nil
        do {
            let loaded = try await client.fetchCurrentUser()
            guard expectedRevision == client.sessionRevision else { return }
            user = loaded
        } catch {
            guard expectedRevision == client.sessionRevision else {
                onSessionChanged()
                return
            }
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

    @MainActor
    func refreshLearningData() async {
        guard isAuthenticated, !isPresentingDemo() else { return }
        let revision = client.sessionRevision
        learningSyncError = nil
        do {
            try await ServerDataProvider.refreshLearningData(client: client, context: learningContext)
            guard revision == client.sessionRevision else { return }
            WidgetCenter.shared.reloadAllTimelines()
        } catch is CancellationError {
            return
        } catch {
            guard revision == client.sessionRevision else { return }
            learningSyncError = error.localizedDescription
        }
    }

    @MainActor
    func logout() {
        client.clearTokens()
        onSessionChanged()
    }

    /// Called when backend URL changes — reset all state.
    @MainActor
    func onBackendChanged() {
        onSessionChanged()
    }

    @MainActor
    func onSessionChanged() {
        guard observedClientRevision != client.sessionRevision else { return }
        observedClientRevision = client.sessionRevision
        sessionRevision = UUID()
        user = nil
        error = nil
        isLoading = false
        learningSyncError = nil
        if learningContext != nil || client === ServerClient.shared {
            do {
                try ServerDataProvider.clearCachedLearningData(context: learningContext)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

//
//  YoungSubscriptionViews.swift
//  Life@USTC
//
//  Event reminders, organizer follows, and subscription management.
//

import SwiftUI

struct YoungEventSubscriptionPanel: View {
    let youngId: String

    @Bindable private var account = ServerAccountStore.shared
    @State private var state: ServerYoungEventSubscriptionState?
    @State private var loadedRevision: UUID?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var failedRequest: YoungEventSubscriptionRequest?

    private var currentState: ServerYoungEventSubscriptionState? {
        account.isAuthenticated && loadedRevision == ServerClient.shared.sessionRevision ? state : nil
    }

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                if let error, loadedRevision == ServerClient.shared.sessionRevision {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry") { Task { await retry() } }.disabled(isLoading || isSaving)
                        .accessibilityIdentifier("young.subscription.retry")
                    YoungReauthorizeButton()
                }
                if let state = currentState {
                    Toggle("Add activity to my calendar", isOn: subscribedBinding).disabled(isSaving || isLoading)
                        .accessibilityIdentifier("young.subscription.enabled")
                    if state.subscribed {
                        Toggle("Signup reminder", isOn: remindSignupBinding).disabled(isSaving || isLoading)
                            .accessibilityIdentifier("young.subscription.signup")
                        Toggle("Deadline reminder", isOn: remindDeadlineBinding).disabled(isSaving || isLoading)
                            .accessibilityIdentifier("young.subscription.deadline")
                        Toggle("Start reminder", isOn: remindStartBinding).disabled(isSaving || isLoading)
                            .accessibilityIdentifier("young.subscription.start")
                        Text("This is a personal reminder and calendar subscription. It does not register attendance.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
        }
        .task(id: account.sessionRevision) { await load() }
    }

    private var subscribedBinding: Binding<Bool> {
        Binding(get: { currentState?.subscribed ?? false }, set: { value in Task { await update(subscribed: value) } })
    }
    private var remindSignupBinding: Binding<Bool> {
        Binding(get: { currentState?.remindSignup ?? false }, set: { value in Task { await update(remindSignup: value) } })
    }
    private var remindDeadlineBinding: Binding<Bool> {
        Binding(get: { currentState?.remindDeadline ?? false }, set: { value in Task { await update(remindDeadline: value) } })
    }
    private var remindStartBinding: Binding<Bool> {
        Binding(get: { currentState?.remindStart ?? false }, set: { value in Task { await update(remindStart: value) } })
    }

    private func load() async {
        let revision = ServerClient.shared.sessionRevision
        if loadedRevision != revision { state = nil; isSaving = false }
        loadedRevision = revision
        error = nil
        failedRequest = nil
        guard account.isAuthenticated else { state = nil; return }
        isLoading = true
        defer { if revision == ServerClient.shared.sessionRevision { isLoading = false } }
        do {
            let result = try await ServerClient.shared.fetchYoungEventSubscription(youngId: youngId)
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            state = result
        } catch is CancellationError {
            return
        } catch {
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func update(
        subscribed: Bool? = nil, remindSignup: Bool? = nil,
        remindDeadline: Bool? = nil, remindStart: Bool? = nil
    ) async {
        guard let current = currentState, !isLoading, !isSaving else { return }
        let revision = ServerClient.shared.sessionRevision
        let request = YoungEventSubscriptionRequest(subscribed: subscribed ?? current.subscribed,
            remindSignup: remindSignup ?? current.remindSignup, remindDeadline: remindDeadline ?? current.remindDeadline,
            remindStart: remindStart ?? current.remindStart)
        isSaving = true
        error = nil
        failedRequest = nil
        defer { if revision == ServerClient.shared.sessionRevision { isSaving = false } }
        do {
            let result = try await ServerClient.shared.updateYoungEventSubscription(
                youngId: youngId, subscribed: request.subscribed,
                remindSignup: request.remindSignup ?? current.remindSignup,
                remindDeadline: request.remindDeadline ?? current.remindDeadline,
                remindStart: request.remindStart ?? current.remindStart, expectedRevision: revision)
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            state = result
        } catch is CancellationError {
            return
        } catch {
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
            failedRequest = request
        }
    }

    private func retry() async {
        if let request = failedRequest {
            await update(subscribed: request.subscribed, remindSignup: request.remindSignup,
                         remindDeadline: request.remindDeadline, remindStart: request.remindStart)
        } else { await load() }
    }
}

struct YoungOrganizerFollowPanel: View {
    let organizerId: String

    @Bindable private var account = ServerAccountStore.shared
    @State private var state: ServerYoungOrganizerSubscriptionState?
    @State private var loadedRevision: UUID?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var failedSubscription: Bool?

    private var currentState: ServerYoungOrganizerSubscriptionState? {
        account.isAuthenticated && loadedRevision == ServerClient.shared.sessionRevision ? state : nil
    }

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                if let error, loadedRevision == ServerClient.shared.sessionRevision {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry") { Task { await retry() } }.disabled(isLoading || isSaving)
                        .accessibilityIdentifier("young.follow.retry")
                    YoungReauthorizeButton()
                }
                if currentState != nil {
                    Toggle("Follow organizer", isOn: followBinding).disabled(isSaving || isLoading)
                        .accessibilityIdentifier("young.follow.enabled")
                    Text("Following this organizer does not subscribe you to its activities.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
        }
        .task(id: account.sessionRevision) { await load() }
    }

    private var followBinding: Binding<Bool> {
        Binding(get: { currentState?.subscribed ?? false }, set: { value in Task { await update(subscribed: value) } })
    }

    private func load() async {
        let revision = ServerClient.shared.sessionRevision
        if loadedRevision != revision { state = nil; isSaving = false }
        loadedRevision = revision
        error = nil
        failedSubscription = nil
        guard account.isAuthenticated else { state = nil; return }
        isLoading = true
        defer { if revision == ServerClient.shared.sessionRevision { isLoading = false } }
        do {
            let result = try await ServerClient.shared.fetchYoungOrganizerSubscription(organizerId: organizerId)
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            state = result
        } catch is CancellationError {
            return
        } catch {
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func update(subscribed: Bool) async {
        guard currentState != nil, !isLoading, !isSaving else { return }
        let revision = ServerClient.shared.sessionRevision
        isSaving = true
        error = nil
        failedSubscription = nil
        defer { if revision == ServerClient.shared.sessionRevision { isSaving = false } }
        do {
            let result = try await ServerClient.shared.updateYoungOrganizerSubscription(
                organizerId: organizerId, subscribed: subscribed, expectedRevision: revision)
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            state = result
        } catch is CancellationError {
            return
        } catch {
            guard revision == ServerClient.shared.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
            failedSubscription = subscribed
        }
    }

    private func retry() async {
        if let failedSubscription { await update(subscribed: failedSubscription) }
        else { await load() }
    }
}

@Observable
@MainActor
final class YoungEventSubscriptionsModel {
    private var snapshot: [ServerYoungEventSubscription] = []
    private var loading = false
    private var failure: String?
    private var removingID: String?
    private var failedRemoval: ServerYoungEventSubscription?
    private var loadedRevision: UUID?
    private var generation = 0
    private let client: ServerClient

    init(client: ServerClient = .shared) { self.client = client }

    private var ownsSnapshot: Bool { client.isAuthenticated && loadedRevision == client.sessionRevision }
    var subscriptions: [ServerYoungEventSubscription] { ownsSnapshot ? snapshot : [] }
    var isLoading: Bool { ownsSnapshot && loading }
    var error: String? { ownsSnapshot ? failure : nil }
    var mutatingID: String? { ownsSnapshot ? removingID : nil }

    func load() async {
        let revision = client.sessionRevision
        if loadedRevision != revision {
            snapshot = []
            failure = nil
            failedRemoval = nil
            removingID = nil
            loadedRevision = revision
        }
        guard client.isAuthenticated else { snapshot = []; return }
        generation += 1
        let requestGeneration = generation
        loading = true
        failure = nil
        failedRemoval = nil
        defer { if requestGeneration == generation { loading = false } }
        do {
            let value = try await client.fetchYoungEventSubscriptions()
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            failure = error.localizedDescription
        }
    }

    func remove(_ subscription: ServerYoungEventSubscription) async {
        guard ownsSnapshot, removingID == nil, snapshot.contains(where: { $0.id == subscription.id }) else { return }
        let revision = client.sessionRevision
        removingID = subscription.id
        failure = nil
        failedRemoval = nil
        defer { if revision == client.sessionRevision { removingID = nil } }
        do {
            _ = try await client.updateYoungEventSubscription(
                youngId: subscription.youngId,
                subscribed: false,
                remindSignup: false,
                remindDeadline: false,
                remindStart: false,
                expectedRevision: revision
            )
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            snapshot.removeAll { $0.id == subscription.id }
        } catch is CancellationError {
            return
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            failure = error.localizedDescription
            failedRemoval = subscription
        }
    }

    func retry() async {
        guard ownsSnapshot else { return }
        if let failedRemoval { await remove(failedRemoval) }
        else { await load() }
    }
}

struct YoungEventSubscriptionsView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = YoungEventSubscriptionsModel()

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error = model.error, model.subscriptions.isEmpty && !model.isLoading {
                YoungErrorView(error: error, retry: { Task { await model.retry() } }, reauthorize: true)
            } else if model.subscriptions.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Subscribed Activities",
                    systemImage: "figure.run.circle",
                    description: Text("Activities you add to your calendar will appear here.")
                )
            } else {
                List {
                    if let error = model.error {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.retry() } }
                                .disabled(model.isLoading || model.mutatingID != nil)
                        }
                    }
                    ForEach(model.subscriptions) { subscription in
                        NavigationLink {
                            YoungEventDetailView(youngId: subscription.youngId)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                YoungEventRow(event: subscription.event, basis: .activity)
                                HStack(spacing: 12) {
                                    if subscription.remindSignup {
                                        Label("Signup", systemImage: "bell")
                                    }
                                    if subscription.remindDeadline {
                                        Label("Deadline", systemImage: "bell")
                                    }
                                    if subscription.remindStart {
                                        Label("Start", systemImage: "bell")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(model.mutatingID != nil)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await model.remove(subscription) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("My Activities")
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
    }
}

@Observable
@MainActor
final class YoungOrganizerSubscriptionsModel {
    private var snapshot: [ServerYoungOrganizerSubscription] = []
    private var loading = false
    private var failure: String?
    private var removingID: String?
    private var failedRemoval: ServerYoungOrganizerSubscription?
    private var loadedRevision: UUID?
    private var generation = 0
    private let client: ServerClient

    init(client: ServerClient = .shared) { self.client = client }

    private var ownsSnapshot: Bool { client.isAuthenticated && loadedRevision == client.sessionRevision }
    var subscriptions: [ServerYoungOrganizerSubscription] { ownsSnapshot ? snapshot : [] }
    var isLoading: Bool { ownsSnapshot && loading }
    var error: String? { ownsSnapshot ? failure : nil }
    var mutatingID: String? { ownsSnapshot ? removingID : nil }

    func load() async {
        let revision = client.sessionRevision
        if loadedRevision != revision {
            snapshot = []
            failure = nil
            failedRemoval = nil
            removingID = nil
            loadedRevision = revision
        }
        guard client.isAuthenticated else { snapshot = []; return }
        generation += 1
        let requestGeneration = generation
        loading = true
        failure = nil
        failedRemoval = nil
        defer { if requestGeneration == generation { loading = false } }
        do {
            let value = try await client.fetchYoungOrganizerSubscriptions()
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            failure = error.localizedDescription
        }
    }

    func remove(_ subscription: ServerYoungOrganizerSubscription) async {
        guard ownsSnapshot, removingID == nil, snapshot.contains(where: { $0.id == subscription.id }) else { return }
        let revision = client.sessionRevision
        removingID = subscription.id
        failure = nil
        failedRemoval = nil
        defer { if revision == client.sessionRevision { removingID = nil } }
        do {
            _ = try await client.updateYoungOrganizerSubscription(
                organizerId: subscription.organizerId,
                subscribed: false,
                expectedRevision: revision
            )
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            snapshot.removeAll { $0.id == subscription.id }
        } catch is CancellationError {
            return
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            failure = error.localizedDescription
            failedRemoval = subscription
        }
    }

    func retry() async {
        guard ownsSnapshot else { return }
        if let failedRemoval { await remove(failedRemoval) }
        else { await load() }
    }
}

struct YoungOrganizerSubscriptionsView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = YoungOrganizerSubscriptionsModel()

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error = model.error, model.subscriptions.isEmpty && !model.isLoading {
                YoungErrorView(error: error, retry: { Task { await model.retry() } }, reauthorize: true)
            } else if model.subscriptions.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Followed Organizers",
                    systemImage: "person.2.circle",
                    description: Text("Organizers you follow will appear here.")
                )
            } else {
                List {
                    if let error = model.error {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.retry() } }
                                .disabled(model.isLoading || model.mutatingID != nil)
                        }
                    }
                    ForEach(model.subscriptions) { subscription in
                        NavigationLink {
                            YoungOrganizerDetailView(organizerId: subscription.organizerId)
                        } label: {
                            Label(subscription.organizer.name, systemImage: "person.2")
                        }
                        .disabled(model.mutatingID != nil)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await model.remove(subscription) }
                            } label: {
                                Label("Unfollow", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("Followed Organizers")
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
    }
}

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
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error, state == nil && !isLoading {
                YoungErrorView(error: error, retry: { Task { await load() } }, reauthorize: true)
            } else if let state {
                Toggle("Add activity to my calendar", isOn: subscribedBinding)
                    .disabled(isSaving)
                if state.subscribed {
                    Toggle("Signup reminder", isOn: remindSignupBinding)
                        .disabled(isSaving)
                    Toggle("Deadline reminder", isOn: remindDeadlineBinding)
                        .disabled(isSaving)
                    Toggle("Start reminder", isOn: remindStartBinding)
                        .disabled(isSaving)
                    Text("This is a personal reminder and calendar subscription. It does not register attendance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .overlay {
            if isLoading && state != nil { ProgressView() }
        }
        .task(id: account.isAuthenticated) { await load() }
    }

    private var subscribedBinding: Binding<Bool> {
        Binding(
            get: { state?.subscribed ?? false },
            set: { value in Task { await update(subscribed: value) } }
        )
    }

    private var remindSignupBinding: Binding<Bool> {
        Binding(
            get: { state?.remindSignup ?? false },
            set: { value in Task { await update(remindSignup: value) } }
        )
    }

    private var remindDeadlineBinding: Binding<Bool> {
        Binding(
            get: { state?.remindDeadline ?? false },
            set: { value in Task { await update(remindDeadline: value) } }
        )
    }

    private var remindStartBinding: Binding<Bool> {
        Binding(
            get: { state?.remindStart ?? false },
            set: { value in Task { await update(remindStart: value) } }
        )
    }

    private func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        isLoading = true
        error = nil
        do {
            state = try await ServerClient.shared.fetchYoungEventSubscription(youngId: youngId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func update(
        subscribed: Bool? = nil,
        remindSignup: Bool? = nil,
        remindDeadline: Bool? = nil,
        remindStart: Bool? = nil
    ) async {
        guard let current = state else { return }
        isSaving = true
        error = nil
        do {
            state = try await ServerClient.shared.updateYoungEventSubscription(
                youngId: youngId,
                subscribed: subscribed ?? current.subscribed,
                remindSignup: remindSignup ?? current.remindSignup,
                remindDeadline: remindDeadline ?? current.remindDeadline,
                remindStart: remindStart ?? current.remindStart
            )
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

struct YoungOrganizerFollowPanel: View {
    let organizerId: String

    @Bindable private var account = ServerAccountStore.shared
    @State private var state: ServerYoungOrganizerSubscriptionState?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error, state == nil && !isLoading {
                YoungErrorView(error: error, retry: { Task { await load() } }, reauthorize: true)
            } else if let state {
                Toggle("Follow organizer", isOn: followBinding)
                    .disabled(isSaving)
                Text("Following this organizer does not subscribe you to its activities.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .overlay {
            if isLoading && state != nil { ProgressView() }
        }
        .task(id: account.isAuthenticated) { await load() }
    }

    private var followBinding: Binding<Bool> {
        Binding(
            get: { state?.subscribed ?? false },
            set: { value in Task { await update(subscribed: value) } }
        )
    }

    private func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        isLoading = true
        error = nil
        do {
            state = try await ServerClient.shared.fetchYoungOrganizerSubscription(organizerId: organizerId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func update(subscribed: Bool) async {
        isSaving = true
        error = nil
        do {
            state = try await ServerClient.shared.updateYoungOrganizerSubscription(
                organizerId: organizerId,
                subscribed: subscribed
            )
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

@Observable
private final class YoungEventSubscriptionsModel {
    var subscriptions: [ServerYoungEventSubscription] = []
    var isLoading = false
    var error: String?

    private var generation = 0

    func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        generation += 1
        let requestGeneration = generation
        isLoading = true
        error = nil
        do {
            let value = try await ServerClient.shared.fetchYoungEventSubscriptions()
            guard requestGeneration == generation, !Task.isCancelled else { return }
            subscriptions = value
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }

    func remove(_ subscription: ServerYoungEventSubscription) async {
        do {
            _ = try await ServerClient.shared.updateYoungEventSubscription(
                youngId: subscription.youngId,
                subscribed: false,
                remindSignup: false,
                remindDeadline: false,
                remindStart: false
            )
            subscriptions.removeAll { $0.id == subscription.id }
        } catch {
            self.error = error.localizedDescription
        }
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
                YoungErrorView(error: error, retry: { Task { await model.load() } }, reauthorize: true)
            } else if model.subscriptions.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Subscribed Activities",
                    systemImage: "figure.run.circle",
                    description: Text("Activities you add to your calendar will appear here.")
                )
            } else {
                List(model.subscriptions) { subscription in
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
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.remove(subscription) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("My Activities")
        .task(id: account.isAuthenticated) { await model.load() }
        .refreshable { await model.load() }
    }
}

@Observable
private final class YoungOrganizerSubscriptionsModel {
    var subscriptions: [ServerYoungOrganizerSubscription] = []
    var isLoading = false
    var error: String?

    private var generation = 0

    func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        generation += 1
        let requestGeneration = generation
        isLoading = true
        error = nil
        do {
            let value = try await ServerClient.shared.fetchYoungOrganizerSubscriptions()
            guard requestGeneration == generation, !Task.isCancelled else { return }
            subscriptions = value
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }

    func remove(_ subscription: ServerYoungOrganizerSubscription) async {
        do {
            _ = try await ServerClient.shared.updateYoungOrganizerSubscription(
                organizerId: subscription.organizerId,
                subscribed: false
            )
            subscriptions.removeAll { $0.id == subscription.id }
        } catch {
            self.error = error.localizedDescription
        }
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
                YoungErrorView(error: error, retry: { Task { await model.load() } }, reauthorize: true)
            } else if model.subscriptions.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Followed Organizers",
                    systemImage: "person.2.circle",
                    description: Text("Organizers you follow will appear here.")
                )
            } else {
                List(model.subscriptions) { subscription in
                    NavigationLink {
                        YoungOrganizerDetailView(organizerId: subscription.organizerId)
                    } label: {
                        Label(subscription.organizer.name, systemImage: "person.2")
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.remove(subscription) }
                        } label: {
                            Label("Unfollow", systemImage: "person.badge.minus")
                        }
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("Followed Organizers")
        .task(id: account.isAuthenticated) { await model.load() }
        .refreshable { await model.load() }
    }
}

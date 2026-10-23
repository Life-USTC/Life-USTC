//
//  YoungNotificationsView.swift
//  Life@USTC
//
//  Personal Second Classroom notification inbox.
//

import SwiftUI

@Observable
@MainActor
final class YoungNotificationsModel {
    var unreadOnly = false
    private var snapshot: [ServerYoungNotification] = []
    private var loadedRevision: UUID?
    private var loadedUnreadOnly: Bool?
    private var loading = false
    private var failure: String?
    private var reading: String?
    private var failedRead: ServerYoungNotification?
    private var generation = 0
    private let client: ServerClient

    init(client: ServerClient = .shared) { self.client = client }

    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision && loadedUnreadOnly == unreadOnly
    }
    var notifications: [ServerYoungNotification] { ownsSnapshot ? snapshot : [] }
    var isLoading: Bool { ownsSnapshot && loading }
    var error: String? { ownsSnapshot ? failure : nil }
    var readingID: String? { ownsSnapshot ? reading : nil }

    func load() async {
        let revision = client.sessionRevision
        let requestedUnreadOnly = unreadOnly
        if loadedRevision != revision || loadedUnreadOnly != requestedUnreadOnly {
            snapshot = []
            failure = nil
            reading = nil
            failedRead = nil
            loadedRevision = revision
            loadedUnreadOnly = requestedUnreadOnly
        }
        guard client.isAuthenticated else { snapshot = []; return }
        generation += 1
        let requestGeneration = generation
        loading = true
        failure = nil
        failedRead = nil
        defer { if requestGeneration == generation { loading = false } }
        do {
            let value = try await client.fetchYoungNotifications(unread: requestedUnreadOnly ? true : nil)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  requestedUnreadOnly == unreadOnly, !Task.isCancelled else { return }
            snapshot = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  requestedUnreadOnly == unreadOnly, !Task.isCancelled else { return }
            failure = error.localizedDescription
        }
    }

    func markRead(_ notification: ServerYoungNotification) async {
        guard ownsSnapshot, !notification.isRead, reading == nil,
              snapshot.contains(where: { $0.id == notification.id }) else { return }
        let revision = client.sessionRevision
        reading = notification.id
        failure = nil
        failedRead = nil
        defer { if revision == client.sessionRevision { reading = nil } }
        do {
            _ = try await client.markYoungNotificationRead(id: notification.id, expectedRevision: revision)
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            await load()
        } catch is CancellationError {
            return
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            failure = error.localizedDescription
            failedRead = notification
        }
    }

    func retry() async {
        guard ownsSnapshot else { return }
        if let failedRead { await markRead(failedRead) }
        else { await load() }
    }
}

struct YoungNotificationsView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = YoungNotificationsModel()

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                List {
                    Picker("Filter reminders", selection: $model.unreadOnly) {
                        Text("All reminders").tag(false)
                        Text("Unread only").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("young.notifications.filter")
                    if let error = model.error {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.retry() } }
                                .disabled(model.isLoading || model.readingID != nil)
                                .accessibilityIdentifier("young.notifications.retry")
                        }
                    }
                    if model.notifications.isEmpty && !model.isLoading && model.error == nil {
                        if model.unreadOnly {
                            ContentUnavailableView("No unread reminders", systemImage: "bell.badge",
                                                   description: Text("You are up to date."))
                        } else {
                            ContentUnavailableView("No Notifications", systemImage: "bell",
                                                   description: Text("You are up to date."))
                        }
                    }
                    ForEach(model.notifications) { notification in notificationRow(notification) }
                    if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                }
            }
        }
        .navigationTitle("Notifications")
        .task(id: "\(account.sessionRevision)-\(model.unreadOnly)") { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
    }

    @ViewBuilder
    private func notificationRow(_ notification: ServerYoungNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(notification.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title).font(.headline)
                Text(YoungFormatting.notificationDescription(notification)).font(.subheadline)
                Text(notification.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                if !notification.isRead {
                    Button("Mark as read") { Task { await model.markRead(notification) } }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(model.readingID != nil || model.isLoading)
                        .accessibilityIdentifier("young.notification.read.\(notification.id)")
                }
                if let youngId = notification.youngId {
                    NavigationLink("Open activity") { YoungEventDetailView(youngId: youngId) }.font(.caption)
                } else if let organizerId = notification.organizerId {
                    NavigationLink("Open organizer") { YoungOrganizerDetailView(organizerId: organizerId) }.font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("young.notification.\(notification.id)")
    }
}

//
//  YoungNotificationsView.swift
//  Life@USTC
//
//  Personal Second Classroom notification inbox.
//

import SwiftUI

@Observable
private final class YoungNotificationsModel {
    var notifications: [ServerYoungNotification] = []
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
            let value = try await ServerClient.shared.fetchYoungNotifications()
            guard requestGeneration == generation, !Task.isCancelled else { return }
            notifications = value
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }

    func markRead(_ notification: ServerYoungNotification) async {
        guard !notification.isRead else { return }
        do {
            _ = try await ServerClient.shared.markYoungNotificationRead(id: notification.id)
            guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
            let current = notifications[index]
            notifications[index] = ServerYoungNotification(
                id: current.id,
                youngId: current.youngId,
                organizerId: current.organizerId,
                kind: current.kind,
                title: current.title,
                body: current.body,
                createdAt: current.createdAt,
                readAt: Date(),
                expiresAt: current.expiresAt
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct YoungNotificationsView: View {
    @State private var model = YoungNotificationsModel()

    var body: some View {
        Group {
            if !ServerClient.shared.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error = model.error, model.notifications.isEmpty && !model.isLoading {
                YoungErrorView(error: error, retry: { Task { await model.load() } }, reauthorize: true)
            } else if model.notifications.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell",
                    description: Text("You are up to date.")
                )
            } else {
                List(model.notifications) { notification in
                    notificationRow(notification)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await model.markRead(notification) }
                        }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("Notifications")
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func notificationRow(_ notification: ServerYoungNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(notification.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.headline)
                Text(notification.body)
                    .font(.subheadline)
                Text(notification.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let youngId = notification.youngId {
                    NavigationLink("Open activity") {
                        YoungEventDetailView(youngId: youngId)
                    }
                    .font(.caption)
                } else if let organizerId = notification.organizerId {
                    NavigationLink("Open organizer") {
                        YoungOrganizerDetailView(organizerId: organizerId)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

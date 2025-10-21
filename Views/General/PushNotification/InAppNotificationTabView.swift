//
//  InAppNotificationTabView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/12.
//

import SwiftUI

struct InAppNotificationTabView: View {
    @ObservedObject var notificationDelegate = InAppNotificationDelegate.shared

    var hasNotifications: Bool {
        !notificationDelegate.notifications.isEmpty
    }

    var body: some View {
        if hasNotifications {
            notificationsTabView
        } else {
            EmptyView()
        }
    }

    private var notificationsTabView: some View {
        TabView {
            ForEach(notificationDelegate.notifications) { notification in
                notificationCard(for: notification)
            }
        }
        .frame(height: 145)
        .padding(10)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
    }

    @ViewBuilder
    private func notificationCard(for notification: InAppNotification) -> some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 15.0)
                .fill(notification.color.opacity(0.9))

            // Content
            VStack(alignment: .leading) {
                notificationHeader(for: notification)

                Divider()
                    .frame(minHeight: 2)
                    .overlay(Color.white)

                Text(notification.message)
                    .padding(.horizontal)

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func notificationHeader(for notification: InAppNotification) -> some View {
        HStack(alignment: .lastTextBaseline) {
            // Left side - Icon and info
            Image(systemName: notification.infolabel)
            Text(notification.infoMessage).fontWeight(.semibold)

            Spacer()

            // Dismiss button
            Image(systemName: "xmark")
                .onTapGesture {
                    notificationDelegate.removeNotification(notification)
                }
        }
        .padding(.horizontal)
    }
}

struct InAppNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { InAppNotificationTabView() }
    }
}

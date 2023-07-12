//
//  InAppNotificationTabView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/12.
//

import SwiftUI

struct InAppNotificationTabView: View {
    @ObservedObject var notificationDelegate = InAppNotificationDelegate.shared
    var mainView: some View {
        TabView {
            ForEach(notificationDelegate.notifications) { notification in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 15.0)
                        .fill(notification.color)
                    VStack(alignment: .leading) {
                        HStack(alignment: .lastTextBaseline) {
                            Image(systemName: notification.infolabel)
                                .font(.caption)
                            Text(notification.infoMessage)
                                .font(.footnote)

                            Spacer()

                            Image(systemName: "xmark")
                                .font(.caption)
                                .onTapGesture {
                                    notificationDelegate.removeNotification(notification)
                                }
                        }
                        .padding(.horizontal)

                        Divider()
                            .frame(minHeight: 1.5)
                            .overlay(Color.white)

                        Text(notification.message)
                            .padding(.horizontal)

                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical)
                }
                .frame(width: 380, height: 150)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .frame(width: 400, height: 150)
    }

    var body: some View {
        if notificationDelegate.notifications.isEmpty {
            EmptyView()
        } else {
            mainView
        }
    }
}

struct InAppNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            InAppNotificationTabView()
        }
    }
}

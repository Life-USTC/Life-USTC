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
                        .fill(notification.color.opacity(0.9))
                    VStack(alignment: .leading) {
                        HStack(alignment: .lastTextBaseline) {
                            Image(systemName: notification.infolabel)
                            Text(notification.infoMessage).fontWeight(.semibold)
                            Spacer()

                            Image(systemName: "xmark")
                                .onTapGesture {
                                    notificationDelegate.removeNotification(
                                        notification
                                    )
                                }
                        }
                        .padding(.horizontal)

                        Divider().frame(minHeight: 2).overlay(Color.white)

                        Text(notification.message).padding(.horizontal)

                        Spacer()
                    }
                    .foregroundColor(.white).padding(.vertical, 10)
                }
            }
        }
        .frame(height: 145).padding(10)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
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
        NavigationStack { InAppNotificationTabView() }
    }
}

//
//  NotificationPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

#if os(iOS)
struct NotificationSettingView: View {
    var body: some View {
        NavigationStack {
            List {
                Button {
                    tryRequestAuthorization()
                    UIApplication.shared.registerForRemoteNotifications()
                } label: {
                    Label("Upload Token", systemImage: "square.and.arrow.up")
                }

                Button {
                    tryRequestAuthorization()
                    let uuidString = UUID().uuidString
                    let content = UNMutableNotificationContent()
                    content.title = "TestTitle"
                    content.body = "What the fuck is this"

                    // set trigger to nil to instantly trigger a update
                    let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                } label: {
                    Label("Test Message", systemImage: "plus.square.dashed")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitle("Notification Settings", displayMode: .inline)
        }
    }
}
#endif

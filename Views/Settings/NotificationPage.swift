//
//  NotificationPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

#if os(iOS)
struct NotificationSettingView: View {
    @AppStorage("useNotification", store: userDefaults) var useNotification = false
    var body: some View {
        NavigationStack {
            List {
                Toggle("Allow Notification", isOn: $useNotification)
                    .onChange(of: useNotification) { newValue in
                        if newValue {
                            tryRequestAuthorization()
                            UIApplication.shared.registerForRemoteNotifications()
                        } else {
                            Task {
                                try await unRegisterDeviceToken()
                            }
                        }
                    }
            }
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .navigationBarTitle("Notification Settings", displayMode: .inline)
        }
    }
}
#endif

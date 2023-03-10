//
//  NotificationPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

#if os(iOS)
struct NotificationSettingView: View {
    @AppStorage("useNotification", store: userDefaults) var useNotification = true
    var body: some View {
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
        .scrollContentBackground(.hidden)
        .navigationBarTitle("Notification Settings", displayMode: .inline)
    }
}
#endif

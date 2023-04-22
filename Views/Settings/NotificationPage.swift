//
//  NotificationPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import UIKit

#if os(iOS)
struct NotificationSettingView: View {
    @AppStorage("useNotification", store: userDefaults) var useNotification = true
    @State private var showingAlert = false

    var body: some View {
        List {
            Section {
                Toggle("Allow Notification", isOn: $useNotification)
                    .onChange(of: useNotification) { newValue in
                        if newValue {
                            XGPush.defaultManager().startXG(withAccessID: 1_680_015_447, accessKey: "IOSAEBOQD6US", delegate: nil)
                        } else {
                            XGPush.defaultManager().stopXGNotification()
                        }
                    }

                Button {
                    XGPush.defaultManager().clearTPNSCache()
                    showingAlert = true
                } label: {
                    Text("Clear TPNS Cache")
                }
                .alert("Success", isPresented: $showingAlert) {
                    Button("OK", role: .cancel) {}
                }
            } header: {
                Text("General")
                    .textCase(.none)
            }

#if DEBUG
            Section {} header: {
                Text("Labels")
                    .textCase(.none)
            }
#endif
        }
        .scrollContentBackground(.hidden)
        .navigationBarTitle("Notification Settings", displayMode: .inline)
    }
}

struct NotificationSetting_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationSettingView()
        }
    }
}
#endif

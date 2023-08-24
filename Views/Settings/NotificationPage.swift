//
//  NotificationPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import UIKit

struct NotificationSettingView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @AppStorage("useNotification", store: UserDefaults.appGroup)
    var useNotification = true
    @State private var showingAlert = false

    var body: some View {
        List {

            #if DEBUG && !IOS_SIMULATOR
            // ensure that this isn't shown on preview device
            // as it runs off rossetta (apple chips) so that it's always x86_64
            ScrollView {
                Text(appDelegate.tpnsLog)
            }
            .border(.yellow)
            .frame(height: 150).padding(0)
            #endif

            Section {
                Toggle("Allow Notification", isOn: $useNotification)
                    .onChange(of: useNotification) { newValue in
                        if newValue {
                            appDelegate.startTPNS()
                        } else {
                            appDelegate.stopTPNS()
                        }
                    }

                Button {
                    //                    XGPush.defaultManager().clearTPNSCache()
                    //                    showingAlert = true
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
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSetting_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationSettingView()
                .environmentObject(AppDelegate())
        }
    }
}

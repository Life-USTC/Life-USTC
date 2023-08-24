//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct SettingsView: View {
    @State var searchText = ""
    var body: some View {
        List {
            Section {
                NavigationLink("App Settings", destination: AppSettingPage())
                NavigationLink(
                    "Feed Source Settings",
                    destination: FeedSettingView()
                )
                NavigationLink("Exam Settings", destination: ExamSettingView())
                NavigationLink(
                    "Notification Settings",
                    destination: NotificationSettingView()
                )
                ForEach(SettingsView.availableSettings) { setting in
                    NavigationLink(
                        setting.name.localized,
                        destination: setting.destinationView
                    )
                }
            }

            Section {
                NavigationLink("About Life@USTC", destination: AboutApp())
                NavigationLink("Legal Info", destination: LegalInfoView())
            }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
    }
}

extension SettingsView {
    static var availableSettings: [SettingWithView] {
        SchoolExport.shared.settings
    }
}

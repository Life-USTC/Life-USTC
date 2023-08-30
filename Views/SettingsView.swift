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
                NavigationLink(
                    "App Settings",
                    destination: AppSettingPage()
                )
                NavigationLink(
                    "Home Page Settings",
                    destination: HomeSettingPage()
                )
                NavigationLink(
                    "Feed Source Settings",
                    destination: FeedSettingView()
                )
                NavigationLink(
                    "Exam Settings",
                    destination: ExamSettingView()
                )
                NavigationLink(
                    "Notification Settings",
                    destination: NotificationSettingView()
                )
            } header: {
                Text("General")
                    .textCase(.none)
            }

            Section {
                ForEach(SchoolExport.shared.settings) { setting in
                    NavigationLink(setting.name.localized) {
                        AnyView(
                            setting.destinationView()
                        )
                    }
                }
            } header: {
                Text("School")
                    .textCase(.none)
            }

            Section {
                NavigationLink(
                    "About Life@USTC",
                    destination: AboutApp()
                )
                NavigationLink(
                    "Legal Info",
                    destination: LegalInfoView()
                )
            } header: {
                Text("More")
                    .textCase(.none)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }
}

//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                // NavigationLink("App Settings", destination: AppSettingsPage())
                //     .accessibilityIdentifier("settings_app_settings")
                NavigationLink("Home Page Settings", destination: HomeSettingPage())
                    .accessibilityIdentifier("settings_home_settings")
                NavigationLink("Feed Source Settings", destination: FeedSetingsPage())
                    .accessibilityIdentifier("settings_feed_settings")
                NavigationLink("Exam Settings", destination: ExamSettingsPage())
                    .accessibilityIdentifier("settings_exam_settings")
            } header: {
                Text("General")
                    .textCase(.none)
            }

            Section {
                ForEach(SchoolSystem.current.settings) { setting in
                    NavigationLink(setting.name) {
                        AnyView(setting.destinationView())
                    }
                }
            } header: {
                Text("School")
                    .textCase(.none)
            }

            Section {
                NavigationLink("About Life@USTC", destination: AboutPage())
                    .accessibilityIdentifier("settings_about")
                NavigationLink("Legal Info", destination: LegalPage())
                    .accessibilityIdentifier("settings_legal")
            } header: {
                Text("More")
                    .textCase(.none)
            }
        }
        .navigationTitle("Settings")
    }
}

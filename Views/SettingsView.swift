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
                NavigationLink("App Settings", destination: AppSettingsPage())
                NavigationLink("Home Page Settings", destination: HomeSettingPage())
                NavigationLink("Feed Source Settings", destination: FeedSetingsPage())
                NavigationLink("Exam Settings", destination: ExamSettingsPage())
            } header: {
                Text("General")
                    .textCase(.none)
            }

            Section {
                ForEach(SchoolExport.shared.settings) { setting in
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
                NavigationLink("Legal Info", destination: LegalPage())
            } header: {
                Text("More")
                    .textCase(.none)
            }
        }
        .navigationTitle("Settings")
    }
}

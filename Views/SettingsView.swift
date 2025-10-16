//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("Life-USTC") var lifeUstc = false

    var aboutTitle: LocalizedStringKey {
        lifeUstc ? "About Life@USTC" : "About Study@USTC"
    }

    var body: some View {
        List {
            Section {
                NavigationLink("App Settings", destination: AppSettingPage())
                NavigationLink("Home Page Settings", destination: HomeSettingPage())
                NavigationLink("Feed Source Settings", destination: FeedSettingView())
                NavigationLink("Exam Settings", destination: ExamSettingView())
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
                NavigationLink(aboutTitle, destination: AboutApp())
                NavigationLink("Legal Info", destination: LegalInfoView())
            } header: {
                Text("More")
                    .textCase(.none)
            }
        }
        .navigationTitle("Settings")
    }
}

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
                NavigationLink("Feed Source Settings", destination: FeedSettingView())
                NavigationLink("CAS Settings", destination: CASLoginView.newPage)
#if DEBUG
                NavigationLink("Change User Type", destination: UserTypeView())
#endif
                NavigationLink("Exam Settings", destination: ExamSettingView())
                NavigationLink("Notification Settings", destination: NotificationSettingView())
            }

            Section {
                NavigationLink("About Life@USTC", destination: AboutLifeAtUSTCView())
                NavigationLink("Legal Info", destination: LegalInfoView())
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
    }
}

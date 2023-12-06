//
//  AppPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/3/26.
//

import SwiftUI

struct AppSettingPage: View {
    @AppStorage("scoreViewPreventScreenShot") var preventScreenShot: Bool = false
    @AppStorage(
        "appShouldNOTUpdateAnything",
        store: .appGroup
    ) var appShouldNOTUpdateAnything: Bool = false
    @AppStorage(
        "curriculumChartShouldHideEvening",
        store: .appGroup
    ) var curriculumChartShouldHideEvening: Bool = false
    @AppStorage("useBaiduStatistics") var useBaiduStatistics: Bool = true

    var body: some View {
        List {
            Section {
                Toggle(
                    "Prevent screenshot when showing score",
                    isOn: $preventScreenShot
                )
                Toggle(
                    "Hide evening in Curriculum",
                    isOn: $curriculumChartShouldHideEvening
                )
                Toggle(
                    "Use Baidu Statistics",
                    isOn: $useBaiduStatistics
                )
                #if DEBUG
                Toggle(
                    "Disable update for everything",
                    isOn: $appShouldNOTUpdateAnything
                )
                #endif
            } header: {
                Text("General")
                    .textCase(.none)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationBarTitle("App Settings", displayMode: .inline)
    }
}

struct AppSettingPage_Previews: PreviewProvider {
    static var previews: some View {
        AppSettingPage()
    }
}

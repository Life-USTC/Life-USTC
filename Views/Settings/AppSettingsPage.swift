//
//  AppSettingsPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/3/26.
//

import SwiftUI

struct AppSettingsPage: View {
    @AppStorage("scoreViewPreventScreenShot") var preventScreenShot = false
    @AppStorage("appShouldNOTUpdateAnything", store: .appGroup) var appShouldNOTUpdateAnything = false
    @AppStorage("useBaiduStatistics") var useBaiduStatistics = true
    @AppStorage("widgetCanRefreshNewData", store: .appGroup) var widgetCanRefreshNewData: Bool? = nil

    var body: some View {
        List {
            Section {
                Toggle(
                    "Prevent screenshot when showing score",
                    isOn: $preventScreenShot
                )
                Toggle(
                    "Use Baidu Statistics",
                    isOn: $useBaiduStatistics
                )
                Toggle(
                    "Allow widget to refresh data",
                    isOn: $widgetCanRefreshNewData ?? false
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
        .navigationTitle("App Settings")
    }
}

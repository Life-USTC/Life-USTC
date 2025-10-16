//
//  AppPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/3/26.
//

import SwiftUI

struct AppSettingPage: View {
    @AppStorage("scoreViewPreventScreenShot") var preventScreenShot = false
    @AppStorage("appShouldNOTUpdateAnything", store: .appGroup) var appShouldNOTUpdateAnything = false
    @AppStorage("curriculumChartShouldHideEvening", store: .appGroup) var curriculumChartShouldHideEvening = false
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
                    "Hide evening in Curriculum",
                    isOn: $curriculumChartShouldHideEvening
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

struct AppSettingPage_Previews: PreviewProvider {
    static var previews: some View {
        AppSettingPage()
    }
}

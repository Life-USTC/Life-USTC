//
//  AppPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/3/26.
//

import SwiftUI

struct AppSettingPage: View {
    @AppStorage("useUSTCBackend", store: .appGroup) var useUSTCBackend: Bool = false
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
    @AppStorage("widgetCanRefreshNewData", store: .appGroup) var _widgetCanRefreshNewData: Bool? = nil

    var body: some View {
        List {
            Section {
//                Toggle(
//                    "Use USTC Backend",
//                    isOn: $useUSTCBackend
//                )
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
                    isOn: $_widgetCanRefreshNewData ?? false
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
        .navigationBarTitle("App Settings", displayMode: .inline)
    }
}

struct AppSettingPage_Previews: PreviewProvider {
    static var previews: some View {
        AppSettingPage()
    }
}

//
//  AppPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/3/26.
//

import SwiftUI

struct AppSettingPage: View {
    @AppStorage("useNewUIForTabBar") var useNewUI = true
    @AppStorage("useNewUILayout") var useNewUILayout = false
    var body: some View {
        List {
            Section {
                Toggle("Use new UI for tabBar", isOn: $useNewUI)
                Toggle("Use new UI layout", isOn: $useNewUILayout)
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

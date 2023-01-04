//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI
import SwiftyJSON

@main
struct Life_USTCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    // these four variables are used to deterime which sheet is required tp prompot to the user.
    @State var casLoginSheet: Bool = false
    @AppStorage("firstLogin") var firstLogin: Bool = true
    @AppStorage("semesterID") var semesterID = "281"
    @AppStorage("passportUsername") var ustcCasUsername: String = ""
    @AppStorage("passportPassword") var ustcCasPassword: String = ""

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "square.stack.3d.up")
                }
            FeaturesView()
                .tabItem {
                    Label("Features", systemImage: "square.grid.2x2.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .sheet(isPresented: $firstLogin) {
            UserTypeView(userTypeSheet: $firstLogin)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $casLoginSheet) {
            CASLoginView(casLoginSheet: $casLoginSheet, isInSheet: true, title: "One more step...", displayMode: .large)
                .interactiveDismissDisabled(true)
        }
        .onAppear(perform: onLoadFunction)
    }

    func onLoadFunction() {
        exceptionCall {
            loadMainUstcCasClient()
            try loadMainUstcUgAASClient()
            try loadFeedCache()
        }
    }
}

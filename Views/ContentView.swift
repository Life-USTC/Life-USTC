//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI

@main
struct Life_USTCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
    @AppStorage("passportUsername", store: userDefaults) var ustcCasUsername: String = ""
    @AppStorage("passportPassword", store: userDefaults) var ustcCasPassword: String = ""

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
        if ustcCasUsername.isEmpty, ustcCasPassword.isEmpty {
            // if either of them is empty, no need to pass them to build the client
            casLoginSheet = true
            return
        }
        _ = Task {
            // if the login result fails, present the user with the sheet.
            casLoginSheet = try await !UstcCasClient.main.loginToCAS()
        }
    }
}

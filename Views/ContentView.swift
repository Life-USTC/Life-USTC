//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI

@main
struct Life_USTCApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum HomeViewTab: String, CaseIterable {
    case home
    case feature
    case setting
}

struct ContentView: View {
    // these four variables are used to deterime which sheet is required tp prompot to the user.
    @State var casLoginSheet: Bool = false
    @AppStorage("firstLogin") var firstLogin: Bool = true
    @AppStorage("passportUsername", store: userDefaults) var ustcCasUsername: String = ""
    @AppStorage("passportPassword", store: userDefaults) var ustcCasPassword: String = ""
    @StateObject var globalNavigation: GlobalNavigation = .main
    @State var sideBar: NavigationSplitViewVisibility = .all
    @State var tab: HomeViewTab = .home
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var mainView: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "square.stack.3d.up")
                }
            FeaturesView()
                .tabItem {
                    Label("Features", systemImage: "square.grid.2x2")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
#if DEBUG
            .sheet(isPresented: $firstLogin) {
                UserTypeView(userTypeSheet: $firstLogin)
                    .interactiveDismissDisabled(true)
            }
#endif
                .sheet(isPresented: $casLoginSheet) {
                    CASLoginView.sheet(isPresented: $casLoginSheet)
                }
                .onAppear(perform: onLoadFunction)
    }

    var body: some View {
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
            HStack {
                Spacer(minLength: 70)
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    Group {
                        switch tab {
                        case .home:
                            HomeView()
                        case .feature:
                            FeaturesView()
                        case .setting:
                            SettingsView()
                        }
                    }
                } detail: {
                    globalNavigation.detailView
                }
            }
            .overlay(alignment: .leading) {
                VStack(spacing: 40) {
                    Image("Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 50))
                        .overlay {
                            Circle()
                                .stroke(Color.accentColor, style: .init(lineWidth: 2))
                        }
                    ForEach(HomeViewTab.allCases, id: \.self) { eachTab in
                        Button {
                            columnVisibility = .all
                            tab = eachTab
                        } label: {
                            Group {
                                switch eachTab {
                                case .home:
                                    Label("Home", systemImage: "square.stack.3d.up")
                                case .feature:
                                    Label("Features", systemImage: "square.grid.2x2")
                                case .setting:
                                    Label("Settings", systemImage: "gearshape")
                                }
                            }
                            .foregroundColor(eachTab == tab ? .accentColor : .primary)
                        }
                    }
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 30))
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.systemBackground))
                }
                .frame(width: 70)
            }
        } else {
            mainView
        }
#else
        NavigationSplitView {
            mainView
        } detail: {
            globalNavigation.detailView
        }
        .navigationSplitViewStyle(.balanced)
#endif
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

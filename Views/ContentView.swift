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

    @ViewBuilder func view() -> some View {
        switch self {
        case .home:
            HomeView()
        case .feature:
            FeaturesView()
        case .setting:
            SettingsView()
        }
    }

    @ViewBuilder func label() -> some View {
        switch self {
        case .home:
            Label("Home", systemImage: "square.stack.3d.up")
        case .feature:
            Label("Features", systemImage: "square.grid.2x2")
        case .setting:
            Label("Settings", systemImage: "gearshape")
        }
    }
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
#if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif

    var iPhoneView: some View {
        TabView(selection: $tab) {
            ForEach(HomeViewTab.allCases, id: \.self) { eachTab in
                eachTab.view()
                    .tabItem {
                        eachTab.label()
                    }
                    .tag(eachTab)
            }
        }
    }

    var sideBarView: some View {
        VStack(spacing: 40) {
            Spacer()
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
                    if tab == eachTab {
                        columnVisibility = .detailOnly
                    } else {
                        columnVisibility = .all
                        tab = eachTab
                    }
                } label: {
                    eachTab.label()
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

    var iPadView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sideBarView
                .navigationSplitViewColumnWidth(80)
                .navigationBarHidden(true)
        }
        content: {
            tab.view()
                .navigationSplitViewColumnWidth(400)
        }
        detail: {
            globalNavigation.detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    var body: some View {
        Group {
#if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
                // iPadOS:
                iPadView
            } else {
                // iOS:
                iPhoneView
            }
#else
            // macOS:
            NavigationSplitView {
                iPhoneView
            } detail: {
                globalNavigation.detailView
            }
            .navigationSplitViewStyle(.balanced)
#endif
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

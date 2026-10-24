//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftData
import SwiftUI

@main
struct Life_USTCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appShouldPresentDemo", store: .appGroup) private var appShouldPresentDemo = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SwiftDataStack.container(forDemo: appShouldPresentDemo))
    }
}

struct ContentView: View {
    @AppStorage("firstLogin_3") var firstLogin = true
    @AppStorage("appShouldPresentDemo", store: .appGroup) private var appShouldPresentDemo = false
    @Bindable private var account = ServerAccountStore.shared

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State var tabSelection: ContentViewTab = .position_1
    @State private var learningRefresh = UUID()
    @State private var contentRoute: ServerContentRoute?

    var iPhoneView: some View {
        Group {
            if #available(iOS 26, *) {
                TabView(selection: $tabSelection) {
                    ForEach(ContentViewTab.allCases, id: \.self) { tab in
                        NavigationStack {
                            tab.view
                        }
                        .tabItem {
                            tab.label
                        }
                        .tag(tab)
                    }
                }
            } else {
                NavigationStack {
                    ContentViewTabBarContainerView(selection: $tabSelection) {
                        ForEach(ContentViewTab.allCases, id: \.self) { tab in
                            tab.view
                                .tabBarItem(tab: tab, selection: $tabSelection)
                            Spacer()
                        }
                    }
                }
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
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.accentColor, style: .init(lineWidth: 2))
                }

            ForEach(ContentViewTab.allCases, id: \.self) { tab in
                Button {
                    tabSelection = tab
                } label: {
                    tab.label.foregroundColor(
                        tab == tabSelection ? tab.color : .primary
                    )
                }
                .accessibilityIdentifier("Tab." + tab.name)
                .keyboardShortcut(
                    KeyEquivalent(Character(String(tab.rawValue))),
                    modifiers: .command
                )
            }
        }
        .labelStyle(.iconOnly)
        .font(.largeTitle)
    }

    var iPadView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sideBarView
                .navigationSplitViewColumnWidth(80)
                .navigationBarHidden(true)
        } detail: {
            NavigationStack {
                tabSelection.view
            }
        }
        .id(tabSelection)
        .navigationSplitViewStyle(.automatic)
    }

    var body: some View {
        Group {
            if firstLogin {
                ServerWelcomeView {
                    firstLogin = false
                }
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
                    iPadView
                } else {
                    iPhoneView
                }
            }
        }
        .id(account.sessionRevision)
        .task { await account.loadUser() }
        .task(id: "\(account.user?.id ?? "anonymous")-\(learningRefresh)-\(appShouldPresentDemo)") {
            if account.user != nil { await account.refreshLearningData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            learningRefresh = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSessionDidChange).receive(on: RunLoop.main)) { notification in
            guard let client = notification.object as? ServerClient, client === ServerClient.shared else { return }
            account.onSessionChanged()
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let route = ServerContentRoute(url: url, baseURL: ServerClient.shared.baseURL) else { return .systemAction }
            contentRoute = route
            return .handled
        })
        .onOpenURL { url in
            contentRoute = ServerContentRoute(url: url, baseURL: ServerClient.shared.baseURL)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                contentRoute = ServerContentRoute(url: url, baseURL: ServerClient.shared.baseURL)
            }
        }
        .sheet(item: $contentRoute) { route in
            NavigationStack {
                ServerContentDestination(route: route)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { contentRoute = nil }
                        }
                    }
            }
            .id(route)
        }
        .modifier(USTCBaseModifier())
    }
}

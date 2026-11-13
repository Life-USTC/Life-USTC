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
    private enum Presentation: Identifiable {
        case content(ServerContentRoute), account(AccountDestination)
        var id: String {
            switch self {
            case .content(let route): "content:\(route.id)"
            case .account(let destination): "account:\(destination.id)"
            }
        }
    }
    @State private var presentation: Presentation?

    private var accountMenu: some View {
        AccountMenu { presentation = .account($0) }
    }

    private func openContent(_ route: ServerContentRoute) {
        tabSelection = ContentViewTab(primaryDestination: route.primaryDestination)
        presentation = route.opensPrimaryRoot ? nil : .content(route)
    }

    var iPhoneView: some View {
        Group {
            if #available(iOS 26, *) {
                TabView(selection: $tabSelection) {
                    ForEach(ContentViewTab.allCases, id: \.self) { tab in
                        NavigationStack {
                            tab.view
                        }
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { accountMenu } }
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
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { accountMenu } }
                }
            }
        }
    }

    var sideBarView: some View {
        VStack(spacing: 40) {
            Spacer()

            accountMenu

            ForEach(ContentViewTab.allCases, id: \.self) { tab in
                Button {
                    tabSelection = tab
                } label: {
                    tab.label.foregroundColor(
                        tab == tabSelection ? tab.color : .primary
                    )
                }
                .accessibilityIdentifier("Tab." + tab.name)
                .accessibilityAddTraits(tab == tabSelection ? .isSelected : [])
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
            openContent(route)
            return .handled
        })
        .onOpenURL { url in
            if let route = ServerContentRoute(url: url, baseURL: ServerClient.shared.baseURL) {
                openContent(route)
            } else {
                presentation = nil
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                if let route = ServerContentRoute(url: url, baseURL: ServerClient.shared.baseURL) {
                    openContent(route)
                } else {
                    presentation = nil
                }
            }
        }
        .onChange(of: account.sessionRevision) { _, _ in presentation = nil }
        .sheet(item: $presentation) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .content(let route): ServerContentDestination(route: route)
                    case .account(let account): account.view
                    }
                }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { presentation = nil }
                                .accessibilityIdentifier("account_destination_done")
                        }
                    }
            }
            .id(destination.id)
        }
        .modifier(USTCBaseModifier())
    }
}

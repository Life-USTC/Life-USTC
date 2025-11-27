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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SwiftDataStack.container)
    }
}

struct ContentView: View {
    @AppStorage("firstLogin_3") var firstLogin = true

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let columnVisibility: NavigationSplitViewVisibility = .all
    @State var tabSelection: ContentViewTab = .position_1

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
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sideBarView
                .navigationSplitViewColumnWidth(80)
                .navigationBarHidden(true)
        } content: {
            tabSelection.view
                .navigationSplitViewColumnWidth(400)
        } detail: {
            EmptyView()
        }
        .navigationSplitViewStyle(.automatic)
    }

    var body: some View {
        Group {
            if firstLogin {
                SchoolSystem.current.firstLoginView($firstLogin)
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
                    iPadView
                } else {
                    iPhoneView
                }
            }
        }
        .modifier(USTCBaseModifier())
    }
}

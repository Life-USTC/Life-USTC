//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI

@main struct Life_USTCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // MARK: - Making iPhone View:

    @State var tabSelection: ContentViewTab = .position_1
    var iPhoneView: some View {
        NavigationStack {
            ContentViewTabBarContainerView(selection: $tabSelection) {
                ForEach(ContentViewTab.allCases, id: \.self) { eachTab in
                    eachTab.view
                        .tabBarItem(tab: eachTab, selection: $tabSelection)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Making iPad View:

    @State var columnVisibility: NavigationSplitViewVisibility = .all
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

            ForEach(ContentViewTab.allCases, id: \.self) { eachTab in
                Button {
                    if tabSelection == eachTab, columnVisibility == .all {
                        columnVisibility = .detailOnly
                    } else {
                        columnVisibility = .all
                        tabSelection = eachTab
                    }
                } label: {
                    eachTab.label.foregroundColor(
                        eachTab == tabSelection ? eachTab.color : .primary
                    )
                }
                .keyboardShortcut(
                    KeyEquivalent(Character(String(eachTab.rawValue))),
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
        } content: {
            tabSelection.view
                .navigationSplitViewColumnWidth(400)
        } detail: {
            EmptyView()
        }
        .navigationSplitViewStyle(.balanced)
    }

    @AppStorage("firstLogin") var firstLogin: Bool = true

    var body: some View {
        // When user first login, present the view here,
        if firstLogin {
            AnyView(
                SchoolExport.shared.firstLoginView($firstLogin)
            )
        } else {
            ZStack {
                // Keep LUJSRuntime in backend and keep alive
                WebView(wkWebView: LUJSRuntime.shared.wkWebView)
                if UIDevice.current.userInterfaceIdiom == .pad,
                    horizontalSizeClass == .regular
                {
                    // iPad:
                    iPadView
                } else {
                    // iOS (including iPad in Stage Manager):
                    iPhoneView
                }
            }
            .modifier(USTCBaseModifier())
        }
    }
}

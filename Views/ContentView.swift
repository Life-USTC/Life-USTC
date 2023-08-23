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
    @AppStorage("firstLogin") var firstLogin: Bool = true
    @State var sideBar: NavigationSplitViewVisibility = .all
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var tabSelection: ContentViewTab = .position_1
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var iPhoneView: some View {
        Group {
            NavigationStack {
                ContentViewTabBarContainerView(selection: $tabSelection) {
                    ForEach(ContentViewTab.allCases, id: \.self) { eachTab in
                        eachTab.view()
                            .tabBarItem(tab: eachTab, selection: $tabSelection)
                        Spacer()
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
                .clipShape(RoundedRectangle(cornerRadius: 50))
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
                    eachTab.label()
                        .foregroundColor(eachTab == tabSelection ? eachTab.color : .primary)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(eachTab.rawValue))), modifiers: [])
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
        } content: {
            tabSelection.view()
                .navigationSplitViewColumnWidth(400)
        } detail: {
            EmptyView()
        }
        .navigationSplitViewStyle(.balanced)
    }

    var body: some View {
        if firstLogin {
            ContentView.firstLoginView($firstLogin)
        } else {
            ZStack {
                WebView(wkWebView: LUJSRuntime.shared.wkWebView)
                if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
                    // iPadOS:
                    iPadView
                        .modifier(ContentView.SharedModifier)
                } else {
                    // iOS:
                    iPhoneView
                        .modifier(ContentView.SharedModifier)
                }
            }
        }
    }
}

private enum ContentViewTab: Int, CaseIterable {
    case position_1 = 1
    case position_2 = 2
    case position_3 = 3

    @ViewBuilder func view() -> some View {
        switch self {
        case .position_1:
            HomeView()
        case .position_2:
            AllSourceView()
        case .position_3:
            FeaturesView()
        }
    }

    var color: Color {
        switch self {
        case .position_1:
            return .accentColor
        case .position_2:
            return .red
        case .position_3:
            return .green
        }
    }

    @ViewBuilder func label() -> some View {
        switch self {
        case .position_1:
            Label("Home", systemImage: "square.stack.3d.up")
        case .position_2:
            Label("Feed", systemImage: "doc.richtext.fill")
        case .position_3:
            Label("Features", systemImage: "square.grid.2x2")
        }
    }
}

private struct ContentViewTabBarItemModifier: ViewModifier {
    let tab: ContentViewTab
    @Binding var selection: ContentViewTab

    func body(content: Content) -> some View {
        if selection == tab {
            content
        } else {
            EmptyView()
        }
    }
}

private extension View {
    func tabBarItem(tab: ContentViewTab, selection: Binding<ContentViewTab>) -> some View {
        modifier(ContentViewTabBarItemModifier(tab: tab, selection: selection))
    }
}

private struct ContentViewTabBarContainerView<Content: View>: View {
    @Binding var selection: ContentViewTab
    let content: Content

    init(selection: Binding<ContentViewTab>, @ViewBuilder content: () -> Content) {
        _selection = selection
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
        }
        .overlay(alignment: .bottom) {
            ContentViewTabBarView(selection: $selection)
        }
    }
}

private struct ContentViewTabBarView: View {
    @Binding var selection: ContentViewTab
    @Namespace private var namespace
    @Environment(\.colorScheme) var colorScheme

    func tabView(tab: ContentViewTab) -> some View {
        tab.label()
            .foregroundColor(selection == tab ? tab.color : Color.gray)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .onTapGesture {
                selection = tab
            }
            .background(
                VStack {
                    if selection == tab {
                        Spacer()
                        RoundedRectangle(cornerRadius: 15)
                            .fill(tab.color.opacity(0.2))
                            .frame(width: 80, height: 5, alignment: .bottom)
                            .clipped()
                            .matchedGeometryEffect(id: "background_rectangle", in: namespace)
                    }
                }
            )
    }

    var body: some View {
        HStack {
            ForEach(ContentViewTab.allCases, id: \.self) { tab in
                tabView(tab: tab)
            }
        }
        .padding(6)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.gray.opacity(0.2))
        }
        .padding(.horizontal)
        .ignoresSafeArea(.keyboard)
    }
}

extension ContentView {
    static var SharedModifier: some ViewModifier {
        //        SchoolExport.shared.baseModifier as! ViewModifier
        //        USTCExports().baseModifier
        USTCBaseModifier()
    }

    static var firstLoginView: (Binding<Bool>) -> AnyView {
        SchoolExport.shared.firstLoginView
    }
}

struct ContentViewTabBarView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(ContentViewTab.allCases, id: \.self) { tab in
                ContentViewTabBarView(selection: .constant(tab))
                    .padding(.vertical, 20)
            }
        }
        .previewDisplayName("TabBar Preview")

        ContentView()
            .previewDisplayName("Main")
    }
}

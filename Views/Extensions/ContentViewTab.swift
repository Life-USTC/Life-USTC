//
//  ContentViewTab.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

enum ContentViewTab: Int, CaseIterable {
    case position_1 = 1
    case position_2 = 2
    case position_3 = 3

    @ViewBuilder
    var view: some View {
        Group {
            switch self {
            case .position_1: HomeView()
            case .position_2: FeaturesView()
            case .position_3: AllSourceView()
            }
        }
    }

    var color: Color {
        switch self {
        case .position_1: return .accentColor
        case .position_2: return .green
        case .position_3: return .red
        }
    }

    var label: some View {
        switch self {
        case .position_1: Label("Home", systemImage: "square.stack.3d.up")
        case .position_2: Label("Features", systemImage: "square.grid.2x2")
        case .position_3: Label("Feed", systemImage: "doc.richtext.fill")
        }
    }
}

struct ContentViewTabBarItemModifier: ViewModifier {
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

extension View {
    func tabBarItem(
        tab: ContentViewTab,
        selection: Binding<ContentViewTab>
    ) -> some View {
        modifier(ContentViewTabBarItemModifier(tab: tab, selection: selection))
    }
}

struct ContentViewTabBarContainerView<Content: View>: View {
    @Binding var selection: ContentViewTab
    let content: Content

    init(
        selection: Binding<ContentViewTab>,
        @ViewBuilder content: () -> Content
    ) {
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

struct ContentViewTabBarView: View {
    @Binding var selection: ContentViewTab
    @Namespace var namespace

    func tabView(tab: ContentViewTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            tab.label
                .foregroundColor(selection == tab ? tab.color : Color.gray)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background {
                    if selection == tab {
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 15)
                                .fill(tab.color.opacity(0.2))
                                .frame(width: 80, height: 5)
                                .matchedGeometryEffect(
                                    id: "background_rectangle",
                                    in: namespace
                                )
                        }
                    }
                }
        }
    }

    var body: some View {
        HStack {
            ForEach(ContentViewTab.allCases, id: \.self) { tab in
                tabView(tab: tab)
            }
        }
        .padding(6)
        .background(Color(uiColor: UIColor.systemBackground))
        .cornerRadius(20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.gray.opacity(0.2))
        }
        .padding(.horizontal)
        .ignoresSafeArea(.keyboard)
    }
}

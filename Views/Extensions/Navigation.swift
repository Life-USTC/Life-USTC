//
//  Navigation.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import SwiftUI

// What a dirty way to make this cross-platform
class GlobalNavigation: ObservableObject {
    static var main = GlobalNavigation()
    @Published var detailView: AnyView = .init(Text("Click on left panel for more information"))

    func updateDetailView(_ newValue: AnyView) {
        detailView = newValue
        objectWillChange.send()
    }
}

@ViewBuilder func NavigationLinkAddon(_ label: LocalizedStringKey, destination: some View) -> some View {
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        NavigationLink {
            destination
        } label: {
            Text(label)
        }
    } else {
        Button {
            GlobalNavigation.main.updateDetailView(AnyView(destination))
        } label: {
            Text(label)
        }
    }
#else
    Text(label)
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination))
        }
#endif
}

@ViewBuilder func NavigationLinkAddon(_ destination: @escaping () -> some View, label: @escaping () -> some View) -> some View {
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        NavigationLink {
            destination()
        } label: {
            label()
        }
    } else {
        Button {
            GlobalNavigation.main.updateDetailView(AnyView(destination()))
        } label: {
            label()
        }
    }
#else
    label()
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination()))
        }
#endif
}

#if os(macOS)
enum NavigationBarItem {
    enum TitleDisplayMode {
        case inline
        case large
        case automatic
    }
}

extension View {
    func navigationBarTitle(_ title: LocalizedStringKey, displayMode _: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(Text(title))
    }

    func navigationBarTitle(_ title: String, displayMode _: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(Text(title))
    }
}
#endif

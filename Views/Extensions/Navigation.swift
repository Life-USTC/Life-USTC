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

struct NavigationLinkAddon: View {
    var destination: () -> AnyView
    var label: () -> AnyView
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    init(_ label: LocalizedStringKey, destination: some View) {
        self.destination = { AnyView(destination) }
        self.label = { AnyView(Text(label)) }
    }

    init(_ destination: @escaping () -> some View, label: @escaping () -> some View) {
        self.destination = { AnyView(destination()) }
        self.label = { AnyView(label()) }
    }

    var body: some View {
        // No need to listen to state update as the view would be completely refreshed as horizontalSizeClass changes.
        if UIDevice.current.userInterfaceIdiom == .pad, horizontalSizeClass == .regular {
            Button {
                GlobalNavigation.main.updateDetailView(AnyView(destination()))
            } label: {
                label()
            }
        } else {
            NavigationLink {
                destination()
            } label: {
                label()
            }
        }
    }
}

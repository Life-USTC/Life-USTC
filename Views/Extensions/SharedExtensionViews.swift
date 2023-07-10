//
//  FeatureWithView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct FeatureWithView: Identifiable, Hashable {
    var id = UUID()
    var image: String
    var title: String
    var subTitle: String
    var destinationView: AnyView

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FeatureWithView, rhs: FeatureWithView) -> Bool {
        lhs.id == rhs.id
    }

    init(image: String, title: String, subTitle: String, destinationView: any View) {
        self.image = image
        self.title = title
        self.subTitle = subTitle
        self.destinationView = .init(destinationView)
    }
}

struct SettingWithView: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var destinationView: AnyView

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SettingWithView, rhs: SettingWithView) -> Bool {
        lhs.id == rhs.id
    }

    init(id: UUID = UUID(), name: String, destinationView: AnyView) {
        self.id = id
        self.name = name
        self.destinationView = destinationView
    }
}

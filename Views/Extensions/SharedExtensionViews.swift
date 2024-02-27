//
//  FeatureWithView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct FeatureWithView: Identifiable, Hashable {
    static func == (lhs: FeatureWithView, rhs: FeatureWithView) -> Bool {
        return lhs.id == rhs.id
    }

    var id = UUID()
    var image: String
    var title: String
    var subTitle: String
    var destinationView: () -> any View

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SettingWithView: Identifiable {
    var id = UUID()
    var name: String
    var destinationView: () -> any View
}

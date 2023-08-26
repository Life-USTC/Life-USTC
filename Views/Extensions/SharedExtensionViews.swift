//
//  FeatureWithView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct FeatureWithView: Identifiable {
    var id = UUID()
    var image: String
    var title: String
    var subTitle: String
    var destinationView: () -> any View
}

struct SettingWithView: Identifiable {
    var id = UUID()
    var name: String
    var destinationView: () -> any View
}

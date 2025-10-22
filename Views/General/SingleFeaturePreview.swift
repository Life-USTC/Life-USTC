//
//  SingleFeatureItemView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/17.
//

import SwiftUI

struct SingleFeaturePreview: View {
    var feature: FeatureWithView
    var body: some View {
        NavigationLink {
            AnyView(feature.destinationView())
        } label: {
            Label(feature.title, systemImage: feature.image)
                .labelStyle(FeatureLabelStyle())
        }
    }
}

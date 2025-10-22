//
//  FeaturePreviewCard.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/17.
//

import SwiftUI

struct FeaturePreviewCard: View {
    var body: some View {
        VStack {
            HStack {
                Text("Features")
                    .font(.system(.title2, weight: .medium))
                Spacer()
            }
            FeaturePreview()
        }
        .card()
    }
}

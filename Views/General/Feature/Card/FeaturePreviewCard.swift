//
//  FeaturePreviewCard.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/17.
//

import SwiftUI

struct FeaturePreviewCard: View {

    var body: some View {
        FeaturePreview()
            .asyncStatusOverlay(
                AsyncStatus(local: .valid, refresh: .success),
                text: "Features",
                showLight: false,
                showToolbar: true
            )
            .card()
    }
}

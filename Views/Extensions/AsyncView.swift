//
//  AsyncView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import SwiftUI

struct AsyncViewStatusMask: ViewModifier {
    var status: AsyncViewStatus?

    func body(content: Content) -> some View {
        ZStack {
            if status?.canShowData ?? true {
                content
                    .opacity(status?.isRefreshing ?? false ? 0.5 : 1.0)
            } else {
                Color.white
            }

            if status?.isRefreshing ?? false {
                ProgressView()
            }

            if status == .failure {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

extension View {
    func asyncViewStatusMask(status: AsyncViewStatus?) -> some View {
        modifier(AsyncViewStatusMask(status: status))
    }
}

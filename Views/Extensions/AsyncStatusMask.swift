//
//  AsyncStatusMask.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

private let lightSize = 8.0

struct AsyncStatusMask: ViewModifier {
    var status: AsyncStatus?

    var localStatusLight: some View {
        Circle()
            .fill(status?.local?.color ?? .gray)
            .frame(width: lightSize, height: lightSize)
    }

    var refreshStatusLight: some View {
        Rectangle()
            .fill(status?.refresh?.color ?? .gray)
            .frame(width: lightSize, height: lightSize)
    }

    func body(content: Content) -> some View {
        VStack {
            HStack {
                localStatusLight
                refreshStatusLight
                if status?.refresh == .waiting {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                Spacer()
            }
            content
        }
    }
}

extension View {
    func asyncStatusMask(status: AsyncStatus?) -> some View {
        modifier(AsyncStatusMask(status: status))
    }
}

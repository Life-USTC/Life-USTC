//
//  AsyncStatusMask.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

private let lightSize = 8.0

struct AsyncStatusLight: View {
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

    var body: some View {
        HStack {
            localStatusLight
            refreshStatusLight
        }
    }
}

struct AsyncStatusMask: ViewModifier {
    var status: AsyncStatus?

    var shouldGrayScale: Bool {
        status?.local == .outDated || status?.refresh == .waiting
    }

    var shouldRedact: Bool {
        status?.local ?? .notFound == .notFound
    }

    func body(content: Content) -> some View {
        content
            .grayscale(shouldGrayScale ? 0.8 : 0)
            .redacted(reason: shouldRedact ? .placeholder : [])
            .overlay {
                if status?.refresh == .waiting {
                    ProgressView()
                }
            }
    }
}

extension View {
    func asyncStatusOverlay(
        _ status: AsyncStatus?
    ) -> some View {
        modifier(
            AsyncStatusMask(
                status: status
            )
        )
    }
}

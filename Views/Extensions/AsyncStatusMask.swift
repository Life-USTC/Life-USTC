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
    var showLight: Bool = true

    func body(content: Content) -> some View {
        VStack {
            if showLight {
                HStack {
                    AsyncStatusLight(status: status)
                    Spacer()
                }
            }

            switch status?.local ?? .notFound {
            case .valid: content
            case .outDated: content.grayscale(0.8)
            case .notFound: content.redacted(reason: .placeholder)
            }
        }
        .if(status?.refresh == .waiting) {
            $0.overlay {
                ProgressView()
            }
        }
    }
}

extension View {
    func asyncStatusOverlay(
        _ status: AsyncStatus?,
        showLight: Bool = true
    ) -> some View {
        modifier(AsyncStatusMask(status: status, showLight: showLight))
    }
}

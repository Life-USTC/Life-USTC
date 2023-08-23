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
                Spacer()
            }

            switch status?.local ?? .notFound {
            case .valid:
                content
            case .outDated:
                content.grayscale(0.5)
            case .notFound:
                content.redacted(reason: .placeholder)
            }
        }
        .overlay {
            if status?.refresh == .waiting {
                ProgressView()
            }
        }
    }
}

extension View {
    func asyncStatusMask(status: AsyncStatus?) -> some View {
        modifier(AsyncStatusMask(status: status))
    }
}

private extension LocalAsyncStatus {
    var color: Color {
        switch self {
        case .valid:
            return .green
        case .notFound:
            return .red
        case .outDated:
            return .yellow
        }
    }
}

private extension RefreshAsyncStatus {
    var color: Color {
        switch self {
        case .waiting:
            return .yellow
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

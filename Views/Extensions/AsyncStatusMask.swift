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
            .padding(.horizontal)

            if (status?.local ?? .notFound) != .notFound {
                content
            } else {
                Text("Error when handling data")
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

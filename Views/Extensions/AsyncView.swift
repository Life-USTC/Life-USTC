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
                    .if(status?.hasError ?? false) { view in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Spacer()
                                    .frame(width: 5)
                                Image(systemName: "xmark.square.fill")
                                    .foregroundColor(.red)
                                Text(status?.errorMessage ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(lineWidth: 2)
                                    .fill(Color.red.opacity(0.5))
                                    .padding(1)
                                view
                                    .padding(5)
                            }
                        }
                    }
            } else {
                content
                    .redacted(reason: .placeholder)
                    .foregroundColor(.secondary)
                    .blur(radius: 2.0)
            }

            if status?.isRefreshing ?? false {
                ProgressView()
            }
        }
    }
}

extension View {
    func asyncViewStatusMask(status: AsyncViewStatus?) -> some View {
        modifier(AsyncViewStatusMask(status: status))
    }
}

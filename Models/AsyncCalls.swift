//
//  AsyncCalls.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/30.
//

import SwiftUI

enum AsyncViewStatus {
    case inProgress
    case success
    case failure
}

func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>, _ function: @escaping () async throws -> T) {
    status.wrappedValue = .inProgress
    _ = Task {
        do {
            data.wrappedValue = try await function()
            status.wrappedValue = .success
        } catch {
            print(error)
            status.wrappedValue = .failure
        }
    }
}

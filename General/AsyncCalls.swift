//
//  AsyncCalls.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/30.
//

import SwiftUI

/// Instruct how the view should appear to user
enum AsyncViewStatus {
    case inProgress
    case success
    case failure
    case waiting
}

/// Create an async task with given function, and pass the result to data, notify the View with status
func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>, _ function: @escaping () async throws -> T) {
    status.wrappedValue = .inProgress
    Task {
        do {
            status.wrappedValue = .inProgress
            data.wrappedValue = try await function()
            status.wrappedValue = .success
        } catch {
            print(error)
            status.wrappedValue = .failure
        }
    }
}

//
//  AsyncStatus.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import SwiftUI

enum LocalAsyncStatus {
    case valid
    case notFound
    case outDated
}

enum RefreshAsyncStatus: Equatable {
    case waiting
    case success
    case error(String)
}

struct AsyncStatus: Equatable {
    var local: LocalAsyncStatus?
    var refresh: RefreshAsyncStatus?
}

extension RefreshAsyncStatus {
    /// - Warning: Always consider exec on `Opentional<RereshAsyncStatus>` instead of `RefreshAsyncStatus`.
    mutating func exec(_ action: @escaping () async throws -> Void) async throws {
        self = .waiting
        do {
            try await action()
            self = .success
        } catch {
            self = .error(error.localizedDescription)
        }
    }
}

extension RefreshAsyncStatus? {
    mutating func exec(_ action: @escaping () async throws -> Void) async throws {
        self = .waiting
        do {
            try await action()
            self = .success
        } catch {
            self = .error(error.localizedDescription)
        }
    }
}

extension Binding<RefreshAsyncStatus?> {
    func exec(_ action: @escaping () async throws -> Void) async throws {
        wrappedValue = .waiting
        do {
            try await action()
            wrappedValue = .success
        } catch {
            wrappedValue = .error(error.localizedDescription)
        }
    }
}

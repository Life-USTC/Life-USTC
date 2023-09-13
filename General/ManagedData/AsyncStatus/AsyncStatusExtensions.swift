//
//  AsyncStatusExtensions.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

extension RefreshAsyncStatus {
    /// - Warning: Always consider exec on `Opentional<RereshAsyncStatus>` instead of `RefreshAsyncStatus`.
    mutating func exec(_ action: @escaping () async throws -> Void) async throws {
        self = .waiting
        do {
            try await action()
            self = .success
        } catch {
            print(error.localizedDescription)
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
            print(error.localizedDescription)
            self = .error(error.localizedDescription)
        }
    }
}

// Used in SwiftUI struct View where modifying self.wrappedValue might not be possible
extension Binding<RefreshAsyncStatus?> {
    func exec(_ action: @escaping () async throws -> Void) async throws {
        wrappedValue = .waiting
        do {
            try await action()
            wrappedValue = .success
        } catch {
            print(error.localizedDescription)
            wrappedValue = .error(error.localizedDescription)
        }
    }
}

extension LocalAsyncStatus {
    var color: Color {
        switch self {
        case .valid: return .green
        case .notFound: return .red
        case .outDated: return .yellow
        }
    }
}

extension RefreshAsyncStatus {
    var color: Color {
        switch self {
        case .waiting: return .yellow
        case .success: return .green
        case .error: return .red
        }
    }
}

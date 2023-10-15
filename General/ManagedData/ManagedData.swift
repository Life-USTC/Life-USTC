//
//  ManagedData.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

/// Wrapper for local-cached data
@propertyWrapper struct ManagedData<D: ExampleDataProtocol>: DynamicProperty {
    @ObservedObject var local: ManagedLocalDataProtocol<D>
    @ObservedObject var remote: ManagedRemoteUpdateProtocol<D>

    /// - Warning: When not mounted in view, you should always call retrive() function instead of directly get` wrappedValue` to prevent get placeholder data. When async context isn't available, call `retriveLocal()`
    var wrappedValue: D {
        // Returning .example data to build view
        // always wrap the view with .redacted(.placeholder) to prevent showing placeholder data
        if appShouldPresentDemo {
            return .example
        }

        return retriveLocal() ?? .example
    }

    var status: AsyncStatus {
        if appShouldPresentDemo {
            return .init(local: .valid, refresh: .success)
        }

        return .init(local: local.status, refresh: remote.status)
    }

    var shouldRefresh: Bool {
        local.status != .valid && remote.status != .waiting
    }

    func retriveLocal() -> D? {
        if appShouldPresentDemo {
            return .example
        }

        if shouldRefresh {
            triggerRefresh()
        }

        return local.data
    }

    func retrive() async throws -> D? {
        if appShouldPresentDemo {
            return .example
        }

        if shouldRefresh {
            try await refresh()
        }

        return local.data
    }

    private func refresh() async throws {
        if appShouldNOTUpdate {
            return
        }

        if appShouldPresentDemo {
            return
        }

        remote.status = .waiting
        do {
            local.data = try await remote.refresh()
            remote.status = .success
        } catch {
            print(error.localizedDescription)
            remote.status = .error(error.localizedDescription)
        }
    }

    /// Can act like viewController, access on view.refreshable with `_data.triggerRefresh()`
    func triggerRefresh() {
        Task { @MainActor in
            // Waiting random time to avoid racing condition
            try await Task.sleep(
                nanoseconds: UInt64.random(in: 0 ..< 1_000_000_000)
            )

            if remote.refreshTask != nil {
                if try await !remote.refreshTask!.value {
                    throw BaseError.runtimeError("Refresh failed")
                }
                return
            }

            remote.refreshTask = Task {
                do {
                    try await self.refresh()
                    remote.refreshTask = nil
                    return true
                } catch {
                    remote.refreshTask = nil
                    print(error.localizedDescription)
                    throw (error)
                }
            }

            if try await !remote.refreshTask!.value {
                throw BaseError.runtimeError("Refresh failed")
            }
        }
    }

    init(_ source: ManagedDataSource<D>) {
        _local = .init(wrappedValue: source.local)
        remote = source.remote
    }
}

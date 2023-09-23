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

    func retriveLocal() -> D? {
        if appShouldPresentDemo {
            return .example
        }

        if local.status != .valid, remote.status == nil {
            triggerRefresh()
        }

        return local.data
    }

    func retrive() async throws -> D? {
        if appShouldPresentDemo {
            return .example
        }

        if status.local != .valid, remote.status == nil {
            try await refresh()
        }

        return local.data
    }

    func refresh() async throws {
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
            try await self.refresh()
        }
    }

    init(_ source: ManagedDataSource<D>) {
        _local = .init(wrappedValue: source.local)
        remote = source.remote
    }
}

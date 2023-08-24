//
//  ManagedData.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

protocol ExampleDataProtocol {
    static var example: Self { get }
}

extension Array: ExampleDataProtocol where Element: ExampleDataProtocol {
    static var example: Self { [Element.example] }
}

@propertyWrapper
struct ManagedData<D: ExampleDataProtocol>: DynamicProperty {
    @ObservedObject var local: ManagedLocalDataProtocol<D>
    var remote: any ManagedRemoteUpdateProtocol<D>

    var wrappedValue: D {
        if local.status != .valid, refresh == nil {
            triggerRefresh()
        }

        return local.data ?? D.example
    }

    @State var refresh: RefreshAsyncStatus? = nil
    var status: AsyncStatus {
        AsyncStatus(
            local: local.status,
            refresh: refresh
        )
    }

    func retrive() async throws -> D? {
        if status.local != .valid {
            try await refresh()
        }
        return wrappedValue
    }

    func refresh() async throws {
        try await $refresh.exec {
            local.data = try await remote.refresh()
        }
    }

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

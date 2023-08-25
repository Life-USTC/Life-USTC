//
//  ManagedDataSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

// Using class so that ObservableObject can function properly
class ManagedLocalDataProtocol<D>: ObservableObject {
    var data: D?
    var status: LocalAsyncStatus { .notFound }

    init(data: D? = nil) {
        assert(true)
        self.data = data
    }
}

/// Simple protocol to wrap a refresh() func, inherit the protocol with class filled with variables to store inside
protocol ManagedRemoteUpdateProtocol<D> {
    associatedtype D

    func refresh() async throws -> D
}

// Source of truth
struct ManagedDataSource<D> {
    var local: ManagedLocalDataProtocol<D>
    var remote: any ManagedRemoteUpdateProtocol<D>
}

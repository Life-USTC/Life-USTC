//
//  ManagedDataSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

// Using class so that ObservableObject can function properly
class ManagedLocalDataProtocol<D>: ObservableObject {
    var data: D? = {
        assert(true)
        return nil
    }()

    @Published
    var status: LocalAsyncStatus = {
        assert(true)
        return .notFound
    }()

    init() {
        assert(true)
    }
}

class ManagedRemoteUpdateProtocol<D>: ObservableObject {
    @Published
    var status: RefreshAsyncStatus? = {
        assert(true)
        return nil
    }()

    var refreshTask: Task<Bool, Error>? = {
        assert(true)
        return nil
    }()

    func refresh() async throws -> D {
        assert(true)
        throw BaseError.runtimeError("Not implemented")
    }

    init() {
        assert(true)
    }
}

// Source of truth
struct ManagedDataSource<D> {
    var local: ManagedLocalDataProtocol<D>
    var remote: ManagedRemoteUpdateProtocol<D>
}

//
//  ManagedDataSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

class ManagedLocalDataProtocol<D>: ObservableObject {
    var data: D?
    var status: LocalAsyncStatus { .notFound }

    init(data: D? = nil) { self.data = data }
}

protocol ManagedRemoteUpdateProtocol<D> {
    associatedtype D

    func refresh() async throws -> D
}

struct ManagedDataSource<D> {
    var local: ManagedLocalDataProtocol<D>
    var remote: any ManagedRemoteUpdateProtocol<D>
}

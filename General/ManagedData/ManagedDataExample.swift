//
//  ManagedDataExample.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import Foundation

/// Protocol to access D.example to build related view
protocol ExampleDataProtocol {
    static var example: Self { get }
}

/// Avoid writing `extension [D] { static var example }`, just implement ExampleDataProtocol for D instead.
extension Array: ExampleDataProtocol where Element: ExampleDataProtocol {
    static var example: Self {
        [Element.example]
    }
}

class ManagedLocalExampleData<D: ExampleDataProtocol>: ManagedLocalDataProtocol<D> {
    override var data: D? {
        get {
            D.example
        }
        set {
            assert(true)
        }
    }

    override var status: LocalAsyncStatus {
        get {
            .valid
        }
        set {
            assert(true)
        }
    }
}

class ManagedRemoteExampleUpdateDelegate<D: ExampleDataProtocol>: ManagedRemoteUpdateProtocol<D> {
    override func refresh() async throws -> D {
        D.example
    }
}

extension ManagedDataSource {
    static func example<T: ExampleDataProtocol>(_ data: T.Type)
        -> ManagedDataSource<T>
    {
        ManagedDataSource<T>(
            local: ManagedLocalExampleData<T>(),
            remote: ManagedRemoteExampleUpdateDelegate<T>()
        )
    }
}

//
//  ManagedWrapper.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

@propertyWrapper
struct ManagedData<D: Codable>: DynamicProperty {
    let delegate: any ManagedDataProtocol

    var wrappedValue: D? {
        if delegate.status.local != .valid {
            Task.detached {
                try await delegate.refresh()
            }
        }
        return delegate.data as? D
    }

    func userTriggeredRefresh() {
        Task.detached {
            try await delegate.refresh()
        }
    }

    func retrive() async throws -> D? {
        if delegate.status.local != .valid {
            try await delegate.refresh()
        }
        return delegate.data as? D
    }

    init(_ delegate: any ManagedDataProtocol) {
        self.delegate = delegate
    }
}

enum ManagedDataSource {}

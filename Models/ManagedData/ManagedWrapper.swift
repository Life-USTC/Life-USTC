//
//  ManagedWrapper.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI

@propertyWrapper
class ManagedData<D: Codable>: DynamicProperty, ObservableObject {
    let delegate: any ManagedDataProtocol

    @Published var wrappedValue: D? = nil {
        willSet {
            objectWillChange.send()
        }
    }

    @Published var status: AsyncStatus = .init() {
        willSet {
            objectWillChange.send()
        }
    }

    func userTriggeredRefresh() {
        Task {
            do {
                status.refresh = .waiting
                try await self.delegate.refresh()
                wrappedValue = delegate.data as? D
                status.local = delegate.localStatus
                status.refresh = .success
            } catch {
                status.refresh = .error(error.localizedDescription)
            }
        }
    }

    func retrive() async throws -> D? {
        if delegate.localStatus != .valid {
            do {
                status.refresh = .waiting
                try await delegate.refresh()
                wrappedValue = delegate.data as? D
                status.local = delegate.localStatus
                status.refresh = .success
            } catch {
                status.refresh = .error(error.localizedDescription)
            }
        }
        return wrappedValue
    }

    init(_ delegate: any ManagedDataProtocol) {
        self.delegate = delegate
        wrappedValue = delegate.data as? D
        status.local = delegate.localStatus

        if delegate.localStatus != .valid {
            userTriggeredRefresh()
        }
    }

    convenience init(_ source: KeyPath<ManagedDataSource.Type, any ManagedDataProtocol>) {
        self.init(ManagedDataSource.self[keyPath: source])
    }

    convenience init(_ source: KeyPath<ManagedDataSource, any ManagedDataProtocol>) {
        self.init(ManagedDataSource()[keyPath: source])
    }
}

struct ManagedDataSource {}
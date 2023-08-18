//
//  ManagedData.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

protocol ManagedDataProtocol {
    associatedtype D

    // MARK: - ViewModel <-> View

    var data: D? { get }
    var localStatus: LocalAsyncStatus { get }

    // MARK: - View -> ViewModel

    /// Triggered when status.local == .notFound or .outDated, manage status on your own
    func refresh() async throws
}

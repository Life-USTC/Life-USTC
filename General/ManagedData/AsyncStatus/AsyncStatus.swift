//
//  AsyncStatus.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import SwiftUI

/// Status mark for data loaded directly from local storage
enum LocalAsyncStatus {
    case valid
    case notFound
    case outDated
}

/// Status mark for a refresh/update progress
enum RefreshAsyncStatus: Equatable {
    case waiting
    case success
    case error(String)
}

/// Status mark for data cached in local
struct AsyncStatus: Equatable {
    var local: LocalAsyncStatus?
    var refresh: RefreshAsyncStatus?
}

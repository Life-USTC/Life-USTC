//
//  AsyncStatus.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation

enum LocalAsyncStatus {
    case valid
    case notFound
    case outDated
}

enum RefreshAsyncStatus: Equatable {
    case waiting
    case success
    case error(String)
}

struct AsyncStatus {
    var local: LocalAsyncStatus?
    var refresh: RefreshAsyncStatus?
}

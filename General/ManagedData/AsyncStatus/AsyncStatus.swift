//
//  AsyncStatus.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import SwiftUI

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

struct AsyncStatus: Equatable {
    var local: LocalAsyncStatus?
    var refresh: RefreshAsyncStatus?
}

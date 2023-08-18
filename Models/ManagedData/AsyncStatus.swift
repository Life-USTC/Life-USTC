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

    var color: Color {
        switch self {
        case .valid:
            return .green
        case .notFound:
            return .red
        case .outDated:
            return .yellow
        }
    }
}

enum RefreshAsyncStatus: Equatable {
    case waiting
    case success
    case error(String)

    var color: Color {
        switch self {
        case .waiting:
            return .yellow
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

struct AsyncStatus: Equatable {
    var local: LocalAsyncStatus?
    var refresh: RefreshAsyncStatus?
}

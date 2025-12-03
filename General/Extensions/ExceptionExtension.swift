//
//  ExceptionCalls.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/3.
//

import SwiftUI

enum BaseError: Error {
    case runtimeError(String)
    case notImplemented
}

extension BaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .runtimeError(let string): return string
        case .notImplemented: return "Not Implemented"
        }
    }
}

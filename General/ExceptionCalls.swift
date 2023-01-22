//
//  ExceptionCalls.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/3.
//

import SwiftUI

/// Create an async task with given function, and pass the result to data, notify the View with status
func exceptionCall<T>(_ function: @escaping () throws -> T) -> T? {
    do {
        return try function()
    } catch {
        print(error)
    }
    return nil
}

enum BaseError: Error {
    case runtimeError(String)
}

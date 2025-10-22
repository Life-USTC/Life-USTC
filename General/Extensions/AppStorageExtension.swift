//
//  AppStorageExtension.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

/// Extension to support optional AppStorage values with default values
extension AppStorage where Value: ExpressibleByNilLiteral {
    /// Initialize AppStorage with optional Bool and default value
    /// - Parameters:
    ///   - wrappedValue: The default value to use if no value exists in UserDefaults
    ///   - key: The key to store the value in UserDefaults
    ///   - store: Optional UserDefaults instance, defaults to standard
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool? {
        self.init(key, store: store)
        if let _ = (store ?? UserDefaults.standard).object(forKey: key) {
            return
        }
        self.wrappedValue = wrappedValue
    }

    /// Initialize AppStorage with optional Int and default value
    /// - Parameters:
    ///   - wrappedValue: The default value to use if no value exists in UserDefaults
    ///   - key: The key to store the value in UserDefaults
    ///   - store: Optional UserDefaults instance, defaults to standard
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int? {
        self.init(key, store: store)
        if let _ = (store ?? UserDefaults.standard).object(forKey: key) {
            return
        }
        self.wrappedValue = wrappedValue
    }
}

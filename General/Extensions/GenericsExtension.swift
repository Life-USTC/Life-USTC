//
//  GenericsExtension.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

/// Enable @AppStorage for Array of Codable elements
/// Allows storing arrays directly in UserDefaults by encoding/decoding as JSON
extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

/// Enable @AppStorage for Dictionary with String keys and Codable values
/// Allows storing dictionaries directly in UserDefaults by encoding/decoding as JSON
extension Dictionary: @retroactive RawRepresentable where Key == String, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else { return "{}" }
        return result
    }
}

/// Provides safe array/collection access to avoid index out of range errors
/// Usage: `array[safe: index]` returns `Element?` instead of crashing
extension Collection where Indices.Iterator.Element == Index {
    public subscript(safe index: Index) -> Iterator.Element? {
        (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}

/// Provides .next() method for CaseIterable enums to cycle through cases
/// Automatically wraps around to the first case after the last one
extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

/// Provides categorise() method to group sequences by a key function
/// Similar to pandas groupby or SQL GROUP BY
/// - Parameter key: Function to extract the grouping key from each element
/// - Returns: Dictionary mapping keys to arrays of elements
extension Sequence {
    public func categorise<U: Hashable>(_ key: (Iterator.Element) -> U) -> [U: [Iterator.Element]] {
        var dict: [U: [Iterator.Element]] = [:]
        for el in self {
            let key = key(el)
            if case nil = dict[key]?.append(el) { dict[key] = [el] }
        }
        return dict
    }
}

/// Custom modulo operator that handles negative numbers correctly
/// Unlike Swift's default %, this always returns a positive result
infix operator %%

extension Int {
    /// Modulo operation that always returns positive result
    /// - Parameters:
    ///   - left: Dividend
    ///   - right: Divisor
    /// - Returns: Positive remainder
    static func %% (_ left: Int, _ right: Int) -> Int {
        if left >= 0 { return left % right }
        if left >= -right { return (left + right) }
        return ((left % right) + right) % right
    }
}

/// Automatic Equatable implementation for Identifiable types
/// Uses id for equality comparison
extension Equatable where Self: Identifiable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

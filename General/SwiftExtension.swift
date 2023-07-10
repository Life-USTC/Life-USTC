//
//  SwiftExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import CryptoKit
import Foundation
import SwiftUI

func doubleForEach<T: Equatable>(_ array: [T], _ function: @escaping (T, T) -> Void) {
    for element in array {
        for secondElement in array {
            if element == secondElement {
                break
            }
            function(element, secondElement)
        }
    }
}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}

extension String {
    /// Return md5 hash in hex string
    ///
    /// - Authors: See https://stackoverflow.com/a/56578995/18417441 ; CC BY-SA 4.0
    var md5HexString: String {
        let digest = Insecure.MD5.hash(data: data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func limitShow(_: Int) -> String {
        "\(String(prefix(6)))\(count > 6 ? "..." : "")"
    }

    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

func combine(_ lhs: String, _ rhs: String) -> String {
    if lhs == rhs {
        return lhs
    } else {
        return "\(lhs) & \(rhs)"
    }
}

public extension Collection where Indices.Iterator.Element == Index {
    subscript(safe index: Index) -> Iterator.Element? {
        (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}

extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

// Optional Binding
func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

prefix func ! <T>(lhs: Binding<T?>) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue! },
        set: { lhs.wrappedValue = $0 }
    )
}

extension String {
    /// Credit: https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        let versionDelimiter = "."

        var versionComponents = components(separatedBy: versionDelimiter) // <1>
        var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

        let zeroDiff = versionComponents.count - otherVersionComponents.count // <2>

        if zeroDiff == 0 { // <3>
            // Same format, compare normally
            return compare(otherVersion, options: .numeric)
        } else {
            let zeros = Array(repeating: "0", count: abs(zeroDiff)) // <4>
            if zeroDiff > 0 {
                otherVersionComponents.append(contentsOf: zeros) // <5>
            } else {
                versionComponents.append(contentsOf: zeros)
            }
            return versionComponents.joined(separator: versionDelimiter)
                .compare(otherVersionComponents.joined(separator: versionDelimiter), options: .numeric) // <6>
        }
    }
}

func isInWidget() -> Bool {
    guard let extesion = Bundle.main.infoDictionary?["NSExtension"] as? [String: String] else { return false }
    guard let widget = extesion["NSExtensionPointIdentifier"] else { return false }
    return widget == "com.apple.widgetkit-extension"
}

public extension Sequence {
    func categorise<U: Hashable>(_ key: (Iterator.Element) -> U) -> [U: [Iterator.Element]] {
        var dict: [U: [Iterator.Element]] = [:]
        for el in self {
            let key = key(el)
            if case nil = dict[key]?.append(el) { dict[key] = [el] }
        }
        return dict
    }
}

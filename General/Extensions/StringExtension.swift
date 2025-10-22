//
//  StringExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import CryptoKit
import SwiftUI

extension String {
    /// Returns the localized version of this string
    /// Uses NSLocalizedString to fetch the translated value
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Returns URL-encoded version of this string
    /// Useful for encoding query parameters in URLs
    /// - Returns: URL-encoded string, or nil if encoding fails
    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    /// Truncates string to specified length and adds ellipsis
    /// - Parameter length: Maximum length before truncation (default: 6)
    /// - Returns: Truncated string with "..." appended, or original if shorter than limit
    func truncated(length: Int = 6) -> String {
        guard count > length else { return self }
        let endIndex = index(startIndex, offsetBy: length)
        return String(self[..<endIndex]) + "..."
    }

    /// Compares version strings numerically (e.g., "1.0.1" vs "2.1.0")
    /// Handles different length version strings by padding with zeros
    /// - Parameter otherVersion: Version string to compare against
    /// - Returns: ComparisonResult (.orderedAscending, .orderedSame, or .orderedDescending)
    /// - Note: Credit: https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        let versionDelimiter = "."
        var versionComponents = components(separatedBy: versionDelimiter)
        var otherVersionComponents = otherVersion.components(
            separatedBy: versionDelimiter
        )
        let zeroDiff = versionComponents.count - otherVersionComponents.count
        if zeroDiff == 0 { return compare(otherVersion, options: .numeric) }
        let zeros = Array(repeating: "0", count: abs(zeroDiff))
        if zeroDiff > 0 {
            otherVersionComponents.append(contentsOf: zeros)
        } else {
            versionComponents.append(contentsOf: zeros)
        }
        return versionComponents.joined(separator: versionDelimiter)
            .compare(
                otherVersionComponents.joined(separator: versionDelimiter),
                options: .numeric
            )
    }
}

/// Enables LocalizedStringKey to be used as Dictionary key and in Sets
extension LocalizedStringKey: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: self))
    }
}

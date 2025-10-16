//
//  StringExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import CryptoKit
import SwiftUI

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    /// Limit length of string
    func truncated(length: Int = 6) -> String {
        guard count > length else { return self }
        let endIndex = index(startIndex, offsetBy: length)
        return String(self[..<endIndex]) + "..."
    }

    /// Compare version number: (1.0.1 , 2.1.0, ....)
    /// - Description: Credit: https://sarunw.com/posts/how-to-compare-two-app-version-strings-in-swift/
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

extension LocalizedStringKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: self))
    }
}

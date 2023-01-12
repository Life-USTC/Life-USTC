//
//  SwiftExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import CryptoKit
import Foundation

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
        return NSLocalizedString(self, comment: "")
    }
}

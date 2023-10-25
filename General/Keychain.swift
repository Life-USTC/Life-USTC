//
//  Keychain.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/23.
//

import KeychainAccess
import SwiftUI

@propertyWrapper public struct AppSecureStorage: DynamicProperty {
    private let key: String
    private let keychain = Keychain(
        service: "com.linzihan.XZKDiOS",
        accessGroup: "group.com.linzihan.XZKDiOS"
    )

    public var wrappedValue: String {
        get { try! keychain.getString(key) ?? "" }
        nonmutating set { keychain[key] = newValue }
    }

    public init(_ key: String) { self.key = key }
}

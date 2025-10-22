//
//  Keychain.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/23.
//

import KeychainAccess
import SwiftUI

@propertyWrapper struct AppSecureStorage: DynamicProperty {
    let key: String
    let keychain = Keychain(
        service: "dev.tiankaima.Life-USTC",
        accessGroup: "group.dev.tiankaima.Life-USTC"
    )

    var wrappedValue: String {
        get { try! keychain.getString(key) ?? "" }
        nonmutating set { keychain[key] = newValue }
    }

    init(_ key: String) { self.key = key }
}

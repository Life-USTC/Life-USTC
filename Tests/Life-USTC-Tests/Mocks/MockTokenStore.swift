//
//  MockTokenStore.swift
//  Life-USTC-Tests
//
//  In-memory token store for unit testing.
//

import Foundation
@testable import Life_USTC

/// In-memory TokenStore for use in tests without touching Keychain.
final class MockTokenStore: TokenStore, @unchecked Sendable {
    var accessToken: String = ""
    var refreshToken: String = ""

    func clear() {
        accessToken = ""
        refreshToken = ""
    }
}

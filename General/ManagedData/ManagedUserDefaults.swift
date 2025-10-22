//
//  ManagedUserDefaults.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

/// Wrapper for UserDefaults
class ManagedUserDefaults<D: Codable>: ManagedLocalDataProtocol<D> {
    let key: String
    let userDefaults: UserDefaults
    let validDuration: TimeInterval

    override var data: D? {
        get {
            guard let data = userDefaults.data(forKey: key) else {
                return nil
            }
            return try? JSONDecoder().decode(D.self, from: data)
        }
        set {
            if let newValue {
                try? userDefaults.set(
                    JSONEncoder().encode(newValue),
                    forKey: key
                )
                lastUpdated = Date()
                objectWillChange.send()
            }
        }
    }

    override var status: LocalAsyncStatus {
        get {
            guard data != nil, let lastUpdated else {
                return .notFound
            }
            guard Date().timeIntervalSince(lastUpdated) < validDuration else {
                return .outDated
            }
            return .valid
        }
        set {
            assert(true)
        }
    }

    var lastUpdated: Date? {
        get {
            userDefaults.object(forKey: key + "_lastUpdated") as? Date
        }
        set {
            userDefaults.set(newValue, forKey: key + "_lastUpdated")
            objectWillChange.send()
        }
    }

    init(
        _ key: String,
        userDefaults: UserDefaults = UserDefaults.appGroup,
        validDuration: TimeInterval = 60 * 15
    ) {
        self.key = key
        self.userDefaults = userDefaults
        self.validDuration = validDuration
    }
}

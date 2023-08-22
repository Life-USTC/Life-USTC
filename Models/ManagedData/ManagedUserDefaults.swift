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
            if let data = userDefaults.data(forKey: key) {
                return try? JSONDecoder().decode(D.self, from: data)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                try? userDefaults.set(JSONEncoder().encode(newValue), forKey: key)
                lastUpdated = Date()
                self.objectWillChange.send()
            }
        }
    }

    override var localStatus: LocalAsyncStatus {
        if data != nil, let lastUpdated {
            if Date().timeIntervalSince(lastUpdated) < validDuration {
                return .valid
            } else {
                return .outDated
            }
        } else {
            return .notFound
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

    init(_ key: String,
         userDefaults: UserDefaults = UserDefaults.appGroup,
         validDuration: TimeInterval = 60 * 15)
    {
        self.key = key
        self.userDefaults = userDefaults
        self.validDuration = validDuration
    }
}

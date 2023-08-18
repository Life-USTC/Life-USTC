//
//  ManagedUserDefaults.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

/// Wrapper for UserDefaults
class ManagedUserDefaults<D: Codable>: ManagedDataProtocol {
    let key: String
    let userDefaults: UserDefaults
    let refreshFunc: () async throws -> D
    let validDuration: TimeInterval

    var data: D? {
        if let data = userDefaults.data(forKey: key) {
            return try? JSONDecoder().decode(D.self, from: data)
        } else {
            return nil
        }
    }

    var lastUpdated: Date? {
        userDefaults.object(forKey: key + "_lastUpdated") as? Date
    }

    var localStatus: LocalAsyncStatus {
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

    func refresh() async throws {
        do {
            let newData = try await refreshFunc()
            let newDataEncoded = try JSONEncoder().encode(newData)
            userDefaults.set(newDataEncoded, forKey: key)
            userDefaults.set(Date(), forKey: key + "_lastUpdated")
        } catch {}
    }

    init(key: String,
         userDefaults: UserDefaults = UserDefaults.appGroup,
         refreshFunc: @escaping () async throws -> D,
         validDuration: TimeInterval = 60 * 15)
    {
        self.key = key
        self.userDefaults = userDefaults
        self.refreshFunc = refreshFunc
        self.validDuration = validDuration
    }
}

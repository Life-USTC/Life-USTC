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
        userDefaults.object(forKey: key) as? D
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

    var refreshStatus: RefreshAsyncStatus? = nil

    var status: AsyncStatus {
        AsyncStatus(local: localStatus,
                    refresh: refreshStatus)
    }

    func refresh() async throws {
        refreshStatus = .waiting
        do {
            let newData = try await refreshFunc()
            userDefaults.set(newData, forKey: key)
            userDefaults.set(Date(), forKey: key + "_lastUpdated")
            refreshStatus = .success
        } catch {
            refreshStatus = .error(error.localizedDescription)
        }
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

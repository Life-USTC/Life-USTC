//
//  ManagedLocalStorage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

/// Wrapper for LocalStorage, stored in fm.documentsDirectory/ManagedLocalStorage/key, lastUpdated is stored in userDefaults
class ManagedLocalStorage<D: Codable>: ManagedDataProtocol {
    let key: String
    let fm: FileManager
    let userDefaults: UserDefaults
    let refreshFunc: () async throws -> D
    let validDuration: TimeInterval

    var url: URL? {
        fm.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("ManagedLocalStorage/\(key)")
    }

    var data: D? {
        if let url {
            return try? JSONDecoder().decode(D.self, from: Data(contentsOf: url))
        }
        return nil
    }

    var lastUpdated: Date? {
        userDefaults.object(forKey: "fm_\(key)_lastUpdated") as? Date
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
            if let url {
                try JSONEncoder().encode(newData).write(to: url)
            }
            userDefaults.set(Date(), forKey: "fm_\(key)_lastUpdated")
            refreshStatus = .success
        } catch {
            refreshStatus = .error(error.localizedDescription)
        }
    }

    init(key: String,
         fm: FileManager = FileManager.default,
         userDefaults: UserDefaults = UserDefaults.appGroup,
         refreshFunc: @escaping () async throws -> D,
         validDuration: TimeInterval = 60 * 15)
    {
        self.key = key
        self.fm = fm
        self.userDefaults = userDefaults
        self.refreshFunc = refreshFunc
        self.validDuration = validDuration
    }
}

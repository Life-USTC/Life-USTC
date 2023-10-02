//
//  ManagedLocalStorage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import Foundation

/// Wrapper for LocalStorage, stored in fm.documentsDirectory/ManagedLocalStorage/key, lastUpdated is stored in userDefaults
class ManagedLocalStorage<D: Codable>: ManagedLocalDataProtocol<D> {
    let key: String
    let fm: FileManager
    let userDefaults: UserDefaults
    let validDuration: TimeInterval

    var url: URL {
        fm
            .containerURL(
                forSecurityApplicationGroupIdentifier:
                    "group.com.linzihan.XZKDiOS"
            )!
            .appendingPathComponent("ManagedLocalStorage/\(key).json")
    }

    override var data: D? {
        get {
            try? JSONDecoder().decode(D.self, from: Data(contentsOf: url))
        }
        set {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            try? JSONEncoder().encode(newValue).write(to: url)
            lastUpdated = Date()
            objectWillChange.send()
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
            userDefaults.object(forKey: "fm_\(key)_lastUpdated") as? Date
        }
        set {
            userDefaults.set(newValue, forKey: "fm_\(key)_lastUpdated")
            objectWillChange.send()
        }
    }

    init(
        _ key: String,
        fm: FileManager = FileManager.default,
        userDefaults: UserDefaults = UserDefaults.appGroup,
        validDuration: TimeInterval = 60 * 15
    ) {
        self.key = key
        self.fm = fm
        self.userDefaults = userDefaults
        self.validDuration = validDuration
    }
}

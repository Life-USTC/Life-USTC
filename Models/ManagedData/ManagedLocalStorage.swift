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

    var url: URL? {
        fm.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("ManagedLocalStorage/\(key).json")
    }

    override var data: D? {
        get {
            if let url {
                return try? JSONDecoder().decode(D.self, from: Data(contentsOf: url))
            }
            return nil
        }
        set {
            print("SET \(key)")
            if let url {
                if !fm.fileExists(atPath: url.path) {
                    try? fm.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true,
                                            attributes: nil)
                }

                try? JSONEncoder().encode(newValue).write(to: url)
                lastUpdated = Date()
            }
            self.objectWillChange.send()
        }
    }

    override var status: LocalAsyncStatus {
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
            userDefaults.object(forKey: "fm_\(key)_lastUpdated") as? Date
        }
        set {
            userDefaults.set(newValue, forKey: "fm_\(key)_lastUpdated")
            objectWillChange.send()
        }
    }

    init(_ key: String,
         fm: FileManager = FileManager.default,
         userDefaults: UserDefaults = UserDefaults.appGroup,
         validDuration: TimeInterval = 60 * 15)
    {
        self.key = key
        self.fm = fm
        self.userDefaults = userDefaults
        self.validDuration = validDuration
    }
}

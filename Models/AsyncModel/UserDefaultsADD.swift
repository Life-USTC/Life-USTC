//
//  UserDefaultsADD.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/23.
//

import Foundation

/// Model that use UserDefaults to store, and implement async Models
protocol UserDefaultsADD: AsyncDataDelegate where C: Codable {
    /// Type for cache
    associatedtype C

    /// Name to store inside userDefaults.
    /// - Warning: Avoid using same names between different instance to avoid conflicts
    var cacheName: String { get }

    /// What to be store and to be parsed.
    /// - Warning: You should call loadCache() inside init, and saveCache() at the end of forceUpdate()
    var cache: C { get set }
}

extension UserDefaultsADD {
    var timeInterval: Double? {
        nil
    }

    func saveCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            let data = try JSONEncoder().encode(self.cache)
            userDefaults.set(data, forKey: self.cacheName)
        }

        // record disk write event
        print("cache<DISK>:\(cacheName) saved")
    }

    func loadCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            if let data = userDefaults.data(forKey: self.cacheName) {
                self.cache = try JSONDecoder().decode(C.self, from: data)
            }
        }

        // record disk read event
        print("cache<DISK>:\(cacheName) loaded")
    }

    func afterForceUpdate() async throws {
        try saveCache()
    }

    func afterInit() {
        exceptionCall {
            try self.loadCache()
        }

        userTriggerRefresh(forced: false)
    }
}

extension UserDefaultsADD where Self: NotifyUserWhenUpdateADD {
    func afterRefreshCache() async throws {
        try saveCache()
        if try await data != parseCache() {
            InAppNotificationDelegate.shared.addInfoMessage(String(format: "%@ have update".localized,
                                                                   nameToShowWhenUpdate.localized))
        }
    }
}

// Overloading the function
// Question posted: https://stackoverflow.com/questions/76431531/how-can-i-check-in-protocol-as-extension-that-whether-or-not-self-follows-pr
extension UserDefaultsADD where Self: LastUpdateADD {
    func saveCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            let data = try JSONEncoder().encode(self.cache)
            userDefaults.set(data, forKey: self.cacheName)
        }

        exceptionCall {
            let data = try JSONEncoder().encode(self.lastUpdate)
            userDefaults.set(data, forKey: self.timeCacheName)
        }

        // record disk write event
        print("cache<DISK>:\(cacheName) saved")
    }

    func loadCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            if let data = userDefaults.data(forKey: self.cacheName) {
                self.cache = try JSONDecoder().decode(C.self, from: data)
            }
        }

        exceptionCall {
            if let data = userDefaults.data(forKey: self.timeCacheName) {
                self.lastUpdate = try JSONDecoder().decode(Date.self, from: data)
            }
        }

        // record disk read event
        print("cache<DISK>:\(cacheName) loaded")
    }

    func afterRefreshCache() async throws {
        lastUpdate = Date()
        try saveCache()
    }

    func afterInit() {
        exceptionCall {
            try self.loadCache()
        }

        userTriggerRefresh(forced: false)
    }
}

extension UserDefaultsADD where Self: LastUpdateADD & NotifyUserWhenUpdateADD {
    func afterRefreshCache() async throws {
        lastUpdate = Date()
        try saveCache()

        if try await data != parseCache() {
            InAppNotificationDelegate.shared.addInfoMessage(String(format: "%@ have update".localized,
                                                                   nameToShowWhenUpdate.localized))
        }
    }
}

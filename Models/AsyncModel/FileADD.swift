//
//  FileADD.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import Foundation

protocol FileADD: AsyncDataDelegate where C: Codable {
    /// Type for cache
    associatedtype C

    // Name to store in document directory
    /// - Warning: Avoid using same names between different instance to avoid conflicts
    var cacheName: String { get }

    /// What to be store and to be parsed.
    /// - Warning: You should call loadCache() inside init, and saveCache() at the end of forceUpdate()
    var cache: C { get set }
}

extension FileADD {
    var timeInterval: Double? {
        nil
    }

    func saveCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            let data = try JSONEncoder().encode(self.cache)
            let fm = FileManager.default
            let url = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = url.appendingPathComponent(self.cacheName)
            try data.write(to: fileURL)
        }

        // record disk write event
        print("cache<DISK>:\(cacheName) saved")
    }

    func loadCache() throws {
        // using two exceptionCall to isolate fatal error
        exceptionCall {
            let fm = FileManager.default
            let url = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = url.appendingPathComponent(self.cacheName)
            let data = try Data(contentsOf: fileURL)
            self.cache = try JSONDecoder().decode(C.self, from: data)
        }

        // record disk read event
        print("cache<DISK>:\(cacheName) loaded")
    }

    func afterRefreshCache() async throws {
        try saveCache()
    }

    func afterInit() {
        exceptionCall {
            try self.loadCache()
        }

        userTriggerRefresh(forced: false)
    }
}

extension FileADD where Self: LastUpdateADD {
    func saveCache() throws {
        exceptionCall {
            let data = try JSONEncoder().encode(self.cache)
            let fm = FileManager.default
            let url = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = url.appendingPathComponent(self.cacheName)
            try data.write(to: fileURL)
        }

        exceptionCall {
            let data = try JSONEncoder().encode(self.lastUpdate)
            userDefaults.set(data, forKey: self.timeCacheName)
        }

        // record disk write event
        print("cache<DISK>:\(cacheName) saved")
    }

    func loadCache() throws {
        exceptionCall {
            let fm = FileManager.default
            let url = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = url.appendingPathComponent(self.cacheName)
            let data = try Data(contentsOf: fileURL)
            self.cache = try JSONDecoder().decode(C.self, from: data)
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

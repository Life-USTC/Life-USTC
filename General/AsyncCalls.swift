//
//  AsyncCalls.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/30.
//

import SwiftUI
import SwiftyJSON

/// Instruct how the view should appear to user
enum AsyncViewStatus {
    case inProgress
    case success
    case failure

    /// In between process from .inProgress -> .sucess. In this stage, the cached data is good to be rendered, just not up-to-date
    case cached

    var canShowData: Bool {
        self == .success || self == .cached || self == .failure
    }

    var isRefreshing: Bool {
        self == .inProgress || self == .cached
    }

    var hasError: Bool {
        self == .failure
    }
}

/// Generic protocol for  Model
protocol AsyncDataDelegate: ObservableObject {
    /// Type for return
    associatedtype D

    var data: D { get set }
    var status: AsyncViewStatus { get set }

    // MARK: - Functions to implement

    /// Whether or not the data should be refreshed before presenting to user.
    /// Often times this is only related to the last time the data is refreshed
    var requireUpdate: Bool { get }

    /// Parse require data from cache.
    /// - Warning: This function isn't supposed to be time-cosuming, but it's async anyway for convenice.
    func parseCache() async throws -> D

    /// Force update the data
    /// - Description: You can wait for network request in this function
    func forceUpdate() async throws

    // MARK: - Functions to call

    /// Get wanted data asynchronously
    func retrive() async throws -> D

    // MARK: - Functions to call in View

    // When user trigger refresh
    func userTriggerRefresh(forced: Bool)
}

/// Calculate requireUpdate according to last time data is updated
protocol LastUpdateADD: AsyncDataDelegate {
    /// Max time before refresh, this should be a constant definition in each model to avoid unnecessary troubles.
    var timeInterval: Double? { get }
    var timeCacheName: String { get }

    /// Manually saving it to userDefaults.key(timeCacheName) is suggested when saving cache
    var lastUpdate: Date? { get set }
}

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

extension AsyncDataDelegate {
    func retrive() async throws -> D {
        if requireUpdate {
            try await forceUpdate()
        }
        return try await parseCache()
    }

    func userTriggerRefresh(forced: Bool = true) {
        Task {
            do {
                data = try await parseCache()
            } catch {
                print(error)

                withAnimation {
                    status = .failure
                }
            }

            if forced || status == .failure || requireUpdate {
                do {
                    withAnimation {
                        if status == .failure {
                            status = .inProgress
                        } else {
                            status = .cached
                        }
                    }

                    try await forceUpdate()
                    data = try await parseCache()
                } catch {
                    print(error)
                    withAnimation {
                        status = .failure
                    }
                    return
                }
            }

            withAnimation {
                status = .success
            }
        }
    }
}

extension LastUpdateADD {
    var requireUpdate: Bool {
        let target = !(lastUpdate != nil && lastUpdate!.addingTimeInterval(timeInterval ?? 7200) > Date())
        print("cache<TIME>:\(timeCacheName), last updated at:\(lastUpdate?.debugDescription ?? "nil"); \(target ? "[Refreshing]" : "[NOT Refreshing]")")
        return target
    }
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
        (self as? any LastUpdateADD)?.lastUpdate = Date()
        try saveCache()
        data = try await parseCache()
    }

    func afterInit() {
        exceptionCall {
            try self.loadCache()
        }

        userTriggerRefresh(forced: false)
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
}

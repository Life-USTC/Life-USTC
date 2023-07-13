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
    // Assuming the original data is never overwritten by incorrect data that might lead the app to crash,
    // So even in event of failure, the views would still be rendered (for user to look at the data with failure)
    //
    // If you don't have the correct data for the view, pass a placeholder
    case failure(String?)

    /// In between process from .inProgress -> .sucess. In this stage, the cached data is good to be rendered, just not up-to-date
    case cached

    var canShowData: Bool {
        switch self {
        case .inProgress:
            return false
        case .success:
            return true
        case .failure:
            return true
        case .cached:
            return true
        }
    }

    var isRefreshing: Bool {
        switch self {
        case .inProgress:
            return true
        case .success:
            return false
        case .failure:
            return false
        case .cached:
            return true
        }
    }

    var hasError: Bool {
        switch self {
        case .inProgress:
            return false
        case .success:
            return false
        case .failure:
            return true
        case .cached:
            return false
        }
    }

    var errorMessage: String {
        switch self {
        case .inProgress:
            return ""
        case .success:
            return ""
        case let .failure(string):
            return string ?? ""
        case .cached:
            return ""
        }
    }
}

/// Generic protocol for  Model
protocol AsyncDataDelegate: ObservableObject {
    /// Type for return
    associatedtype D: Equatable
    var nameToShowWhenUpdate: String? { get }

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

    func foregroundUpdateStatus(with status: AsyncViewStatus) {
        DispatchQueue.main.async {
            withAnimation {
                self.status = status
            }
        }
    }

    func foregroundUpdateData(with data: D) {
        DispatchQueue.main.async {
            withAnimation {
                self.data = data
            }
        }
    }

    func userTriggerRefresh(forced: Bool = true) {
        Task {
            do {
                foregroundUpdateData(with: try await parseCache())
            } catch {
                print(error)
                foregroundUpdateStatus(with: .failure(error.localizedDescription))
            }

            if forced || status.hasError || requireUpdate {
                do {
                    if self.status.hasError {
                        foregroundUpdateStatus(with: .inProgress)
                    } else {
                        foregroundUpdateStatus(with: .cached)
                    }

                    try await forceUpdate()
                } catch {
                    print(error)
                    foregroundUpdateStatus(with: .failure(error.localizedDescription))
                    return
                }
            }

            foregroundUpdateStatus(with: .success)
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
        try saveCache()
        let data = try await parseCache()

        if self.data != data, let name = nameToShowWhenUpdate {
            InAppNotificationDelegate.shared.addInfoMessage(String(format: "%@ have update".localized, name.localized))
        }
        foregroundUpdateData(with: data)
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

    func afterForceUpdate() async throws {
        lastUpdate = Date()
        try saveCache()
        let data = try await parseCache()

        if self.data != data, let name = nameToShowWhenUpdate {
            InAppNotificationDelegate.shared.addInfoMessage(String(format: "%@ have update".localized, name.localized))
        }
        foregroundUpdateData(with: data)
    }

    func afterInit() {
        exceptionCall {
            try self.loadCache()
        }

        userTriggerRefresh(forced: false)
    }
}

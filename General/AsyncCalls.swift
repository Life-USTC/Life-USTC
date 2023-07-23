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
    case cached // In between process from .inProgress -> .sucess. In this stage, the cached data is good to be rendered, just not up-to-date and would be replaced by other status
    case success

    // In ADD, you should always pass a placeholder
    case failure(String?) // if a out-of-date data is available, use this
    case lethalFailure(String?) // if no data is available, use this

    var canShowData: Bool {
        switch self {
        case .inProgress:
            return false
        case .success:
            return true
        case .failure:
            return true
        case .lethalFailure:
            return false
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
        case .lethalFailure:
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
        case .lethalFailure:
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
        case let .lethalFailure(string):
            return string ?? ""
        case .cached:
            return ""
        }
    }
}

/// Generic protocol for  Model
protocol AsyncDataDelegate: ObservableObject {
    /// Type for return
    associatedtype D

    var data: D { get set }
    var placeHolderData: D { get }
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
    func refreshCache() async throws

    // MARK: - Functions to call

    /// Get wanted data asynchronously
    func retrive() async throws -> D

    // MARK: - Functions to call in View

    // When user trigger refresh
    func userTriggerRefresh(forced: Bool)
}

protocol NotifyUserWhenUpdateADD: AsyncDataDelegate where D: Equatable {
    var nameToShowWhenUpdate: String { get }
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
            try await refreshCache()
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

    /// View controller action, all parameters are updated, and this function is called
    /// - Parameters:
    ///     forced: when set to true, a cache won't be used (even if it's still valid)
    ///
    /// - Warning:
    /// forced = true:
    /// inProgress  -> success
    ///
    /// forced = false:
    /// inProgress -> cached -> success
    func userTriggerRefresh(forced: Bool = true) {
        Task {
            if forced {
                // forced:
                do {
                    // Stage 1: Refresh
                    foregroundUpdateStatus(with: .inProgress)
                    try await refreshCache()
                } catch {
                    // refresh failed, try parse from old cache
                    print(error)
                    do {
                        foregroundUpdateData(with: try await parseCache())

                        // Outcome A: the refresh is failed, but data still presents
                        foregroundUpdateStatus(with: .failure(error.localizedDescription))
                        return
                    } catch {
                        // no data could be loaded from old cache, throwing error
                        print(error)

                        // Outcome B: the refresh is failed, and data is lost, return lethal
                        foregroundUpdateData(with: placeHolderData)
                        foregroundUpdateStatus(with: .lethalFailure(error.localizedDescription))
                        return
                    }
                }

                do {
                    // Stage 2: Load from Cache
                    foregroundUpdateData(with: try await parseCache())

                    // MARK: Outcome Main: Desired outcome

                    foregroundUpdateStatus(with: .success)
                    return
                } catch {
                    print(error)

                    // Outcome C: the refresh is successful, but no data presents
                    foregroundUpdateData(with: placeHolderData)
                    foregroundUpdateStatus(with: .lethalFailure(error.localizedDescription))
                    return
                }
            }

            // !forced:
            do {
                // Stage 1: Parse from cache:
                foregroundUpdateStatus(with: .inProgress)
                foregroundUpdateData(with: try await parseCache())
            } catch {
                // If no data could be parsed from cache, try forceUpdate
                print(error)
                do {
                    try await refreshCache()
                    foregroundUpdateData(with: try await parseCache())
                    foregroundUpdateStatus(with: .success)
                    return
                } catch {
                    print(error)
                    foregroundUpdateData(with: placeHolderData)
                    foregroundUpdateStatus(with: .lethalFailure(error.localizedDescription))
                    return
                }
            }

            if requireUpdate {
                do {
                    foregroundUpdateStatus(with: .cached)
                    try await refreshCache()
                } catch {
                    print(error)
                    foregroundUpdateStatus(with: .failure(error.localizedDescription))
                    return
                }

                do {
                    foregroundUpdateData(with: try await parseCache())
                    foregroundUpdateStatus(with: .success)
                } catch {
                    print(error)

                    foregroundUpdateData(with: placeHolderData)
                    foregroundUpdateStatus(with: .lethalFailure(error.localizedDescription))
                    return
                }
            } else {
                foregroundUpdateStatus(with: .success)
                return
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

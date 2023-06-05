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

    @available(*, deprecated)
    case waiting

    var canShowData: Bool {
        self == .success || self == .cached
    }

    var isRefreshing: Bool {
        self == .inProgress || self == .cached
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

    /// Bind the data to view
    /// - Deprecated: Implement @Published instead
    @available(*, deprecated)
    func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>)
    @available(*, deprecated)
    func asyncBind<T>(status: Binding<AsyncViewStatus>, setData: @escaping (T) async throws -> Void)

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
protocol UserDefaultsADD: LastUpdateADD where C: Codable {
    /// Type for cache
    associatedtype C

    /// Name to store inside userDefaults.
    /// - Warning: Avoid using same names between different instance to avoid conflicts
    var cacheName: String { get }

    /// What to be store and to be parsed.
    /// - Warning: You should call loadCache() inside init, and saveCache() at the end of forceUpdate()
    var cache: C { get set }
}

extension LastUpdateADD {
    var requireUpdate: Bool {
        let target = !(lastUpdate != nil && lastUpdate!.addingTimeInterval(timeInterval ?? 7200) > Date())
        print("cache<TIME>:\(timeCacheName), last updated at:\(lastUpdate?.debugDescription ?? "nil"); \(target ? "[Refreshing]" : "[NOT Refreshing]")")
        return target
    }
}

extension AsyncDataDelegate {
    func userTriggerRefresh(forced: Bool = true) {
        Task {
            // This is disabled to continue show previous data
//            withAnimation {
//                status = .inProgress
//            }
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
            if let data = userDefaults.data(forKey: self.timeCacheName) {
                self.lastUpdate = try JSONDecoder().decode(Date?.self, from: data)
            }
        }
        exceptionCall {
            if let data = userDefaults.data(forKey: self.cacheName) {
                self.cache = try JSONDecoder().decode(C.self, from: data)
            }
        }

        // record disk read event
        print("cache<DISK>:\(cacheName) loaded")
    }

    func afterForceUpdate() async throws {
        lastUpdate = Date()
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

// MARK: - Deprecated Defintions:

/// Create an async task with given function, and pass the result to data, notify the View with status
/// - Deprecated: Avoid calling this function in most position, use @Published and @StateObject to listen to change in Model
func asyncBind<T>(_ data: Binding<T>,
                  status: Binding<AsyncViewStatus>,
                  _ function: @escaping () async throws -> T)
{
    status.wrappedValue = .inProgress
    Task {
        do {
            withAnimation {
                status.wrappedValue = .inProgress
            }
            data.wrappedValue = try await function()
            withAnimation {
                status.wrappedValue = .success
            }
        } catch {
            print(error)
            withAnimation {
                status.wrappedValue = .failure
            }
        }
    }
}

extension AsyncDataDelegate {
    func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>) {
        status.wrappedValue = .inProgress
        Task {
            do {
                data.wrappedValue = try await parseCache() as! T
            } catch {
                print(error)
                status.wrappedValue = .failure
            }

            if requireUpdate || status.wrappedValue == .failure {
                do {
                    status.wrappedValue = .cached
                    try await forceUpdate()
                    data.wrappedValue = try await parseCache() as! T
                } catch {
                    print(error)
                    return
                }
            }
            status.wrappedValue = .success
        }
    }

    @available(*, message: "Notice that sometimes the status failed to set to inProgress")
    func asyncBind<T>(status: Binding<AsyncViewStatus>, setData: @escaping (T) async throws -> Void) {
        status.wrappedValue = .inProgress
        Task {
            do {
                try await setData(try await parseCache() as! T)
            } catch {
                print(error)
                status.wrappedValue = .failure
            }

            if requireUpdate || status.wrappedValue == .failure {
                do {
                    status.wrappedValue = .cached
                    try await forceUpdate()
                    try await setData(try await parseCache() as! T)
                } catch {
                    print(error)
                    return
                }
            }
            status.wrappedValue = .success
        }
    }

    func retrive() async throws -> D {
        if requireUpdate {
            try await forceUpdate()
        }
        return try await parseCache()
    }
}

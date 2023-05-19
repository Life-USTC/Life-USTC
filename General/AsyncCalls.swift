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
    case cached
    case success
    case failure
    case waiting
}

/// Create an async task with given function, and pass the result to data, notify the View with status
func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>, _ function: @escaping () async throws -> T) {
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

protocol AsyncDataDelegate: AnyObject {
    associatedtype D // return data type
    var requireUpdate: Bool { get }
    func parseCache() async throws -> D

    /// - Warning: Manually save inside forceUpdate
    func forceUpdate() async throws
    func asyncBind<T>(_ data: Binding<T>, status: Binding<AsyncViewStatus>)
    func retrive() async throws -> D
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

protocol LastUpdateAsyncDataDelegate: AsyncDataDelegate {
    var timeCacheName: String { get }
    var lastUpdate: Date? { get set }
    var timeInterval: Double? { get }
}

extension LastUpdateAsyncDataDelegate {
    var requireUpdate: Bool {
        !(lastUpdate != nil && lastUpdate!.addingTimeInterval(timeInterval ?? 7200) > Date())
    }
}

protocol BaseAsyncDataDelegate: LastUpdateAsyncDataDelegate where D: Codable {
    var cacheName: String { get }
    var cache: D { get set }
}

extension BaseAsyncDataDelegate {
    func parseCache() async throws -> D {
        cache
    }

    func saveCache() throws {
        debugPrint("cache:\(cacheName) saved")
        var data = try JSONEncoder().encode(cache)
        userDefaults.set(data, forKey: cacheName)
        data = try JSONEncoder().encode(lastUpdate)
        userDefaults.set(data, forKey: timeCacheName)
    }

    func loadCache() throws {
        debugPrint("cache:\(cacheName) loaded")
        if let data = userDefaults.data(forKey: timeCacheName) {
            lastUpdate = try JSONDecoder().decode(Date?.self, from: data)
        }
        if let data = userDefaults.data(forKey: cacheName) {
            cache = try JSONDecoder().decode(D.self, from: data)
        }
    }
}

protocol CacheAsyncDataDelegate: LastUpdateAsyncDataDelegate {
    var cacheName: String { get }
    var cache: JSON { get set }
}

extension CacheAsyncDataDelegate {
    func saveCache() throws {
        debugPrint("cache:\(cacheName) saved")
        var data = try cache.rawData()
        userDefaults.set(data, forKey: cacheName)
        data = try JSONEncoder().encode(lastUpdate)
        userDefaults.set(data, forKey: timeCacheName)
    }

    func loadCache() throws {
        debugPrint("cache:\(cacheName) loaded")
        if let data = userDefaults.data(forKey: timeCacheName) {
            lastUpdate = try JSONDecoder().decode(Date?.self, from: data)
        }
        if let data = userDefaults.data(forKey: cacheName) {
            cache = try JSON(data: data)
        } else {
            Task {
                try await forceUpdate()
            }
        }
    }
}

//
//  AsyncDataDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/23.
//

import SwiftUI

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

extension LastUpdateADD {
    var requireUpdate: Bool {
        let target = !(lastUpdate != nil && lastUpdate!.addingTimeInterval(timeInterval ?? 7200) > Date())
        print("cache<TIME>:\(timeCacheName), last updated at:\(lastUpdate?.debugDescription ?? "nil"); \(target ? "[Refreshing]" : "[NOT Refreshing]")")
        return target
    }
}

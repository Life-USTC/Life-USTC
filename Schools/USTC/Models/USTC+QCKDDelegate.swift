//
//  USTC+QCKDDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI
import SwiftyJSON

final class USTCQCKDDelegate: FileADD & LastUpdateADD {
    static var shared = USTCQCKDDelegate()

    // MARK: - Protocol requirements

    typealias D = UstcQCKDModel
    @Published var status: AsyncViewStatus = .inProgress
    @Published var data: UstcQCKDModel = .init()

    var cache: UstcQCKDModel {
        get {
            data
        }
        set {
            data = newValue
        }
    }

    var placeHolderData: UstcQCKDModel = .init()
    var timeInterval: Double?
    var timeCacheName: String = "UstcQCKDClientLastUpdated"
    var cacheName: String = "UstcQCKDClientCache"
    var lastUpdate: Date?

    var ustcQCKDClient = UstcQCKDClient.shared

    func parseCache() async throws -> UstcQCKDModel {
        data
    }

    func refreshCache() async throws {
        // async let availableEvents = ustcQCKDClient.fetchAvailableEvents()
        // async let doneEvents = ustcQCKDClient.fetchDoneEvents()
        // async let myEvents = ustcQCKDClient.fetchMyEvents()

        // data = .init(availableEvents: try await availableEvents,
        //              doneEvents: try await doneEvents,
        //              myEvents: try await myEvents)
        nextPageNo = ["Available": 1, "Done": 1, "My": 1]
        foregroundUpdateData(with: .init(eventLists: await withTaskGroup(of: (String, [UstcQCKDEvent])?.self) { group in
            for name in ["Available", "Done", "My"] {
                group.addTask {
                    do {
                        return (name, try await self.ustcQCKDClient.fetchEventList(with: name))
                    } catch {
                        return nil
                    }
                }
            }

            return await group.reduce(into: [:]) { dictionary, result in
                if let result {
                    dictionary[result.0] = result.1
                }
            }
        }))

        try await afterRefreshCache()
    }

    // var nextPageNo = [1, 1, 1]
    var nextPageNo = ["Available": 1, "Done": 1, "My": 1]

    func fetchMorePage(for type: String) async throws {
        foregroundUpdateStatus(with: .cached)
        var newValue = data
        do {
            // switch type {
            // case "Available":
            //     nextPageNo[0] += 1
            //     newValue.availableEvents += try await ustcQCKDClient.fetchAvailableEvents(pageNo: nextPageNo[0])
            // case "Done":
            //     nextPageNo[1] += 1
            //     newValue.doneEvents += try await ustcQCKDClient.fetchDoneEvents(pageNo: nextPageNo[1])
            // case "My":
            //     nextPageNo[2] += 1
            //     newValue.myEvents += try await ustcQCKDClient.fetchMyEvents(pageNo: nextPageNo[2])
            // default:
            //     return
            // }
            // newValue.eventLists[type]?.append(contentsOf: try await ustcQCKDClient.fetchEventList(with: type, pageNo: nextPageNo[["Available", "Done", "My"].firstIndex(of: type)!]))
            nextPageNo[type]! += 1
            newValue.eventLists[type]?.append(contentsOf: try await ustcQCKDClient.fetchEventList(with: type, pageNo: nextPageNo[type]!))
        } catch {
            foregroundUpdateStatus(with: .failure(error.localizedDescription))
            return
        }
        foregroundUpdateData(with: newValue)
        foregroundUpdateStatus(with: .success)
        try await afterRefreshCache()
    }

    init() {
        afterInit()
    }
}

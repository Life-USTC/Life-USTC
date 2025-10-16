//
//  USTC+BusDelegate.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import Foundation
import SwiftUI
import SwiftyJSON

// Typealias for time strings in "HH:MM" format
typealias TimeString = String

extension TimeString {
    var minutesSinceMidnight: Int {
        let components = self.split(separator: ":")
        return Int(components[0])! * 60 + Int(components[1])!
    }
}

extension [TimeString?] {
    func passed(_ date: Date = Date()) -> Bool {
        return self[0] == nil ? false : self[0]!.minutesSinceMidnight < date.minutesSinceMidnight
    }
}

extension [[TimeString?]] {
    func filterAfter(_ date: Date = Date()) -> [[TimeString?]] {
        return self.filter { !$0.passed(date) }
    }
}

struct USTCCampus: Identifiable, Codable, Hashable {
    var id: Int
    var name: String

    var latitude: Double
    var longitude: Double

    static let example = USTCCampus(
        id: 1,
        name: "东区",
        latitude: 100,
        longitude: 30
    )
}

struct USTCRoute: Identifiable, Codable, Hashable {
    var id: Int
    var campuses: [USTCCampus]

    static let example = USTCRoute(
        id: 1,
        campuses: [.example, .example]
    )
}

struct USTCRouteSchedule: Identifiable, Codable, Equatable {
    var id: Int
    var route: USTCRoute
    var time: [[TimeString?]]

    static let example = USTCRouteSchedule(
        id: 1,
        route: .example,
        time: [
            ["07:50", "08:10"]
        ]
    )

    var routeDescription: String {
        let start = route.campuses.first?.name ?? ""
        let end = route.campuses.last?.name ?? ""
        return "\(start) - \(end)"
    }

    var nextDeparture: [TimeString?]? {
        return time.filter { !$0.passed() }.first
    }
}

struct Message: Codable, Equatable {
    var message: String
    var url: String
}

struct USTCBusData: ExampleDataProtocol, Codable, Equatable {
    var campuses: [USTCCampus]

    var routes: [USTCRoute]

    var weekday_routes: [USTCRouteSchedule]
    var weekend_routes: [USTCRouteSchedule]

    var message: Message?

    static let example = USTCBusData(
        campuses: [.example],
        routes: [.example],
        weekday_routes: [.example],
        weekend_routes: [.example]
    )
}

class USTCBusDataDelegate: ManagedRemoteUpdateProtocol<USTCBusData> {
    static let shared = USTCBusDataDelegate()

    override func refresh() async throws -> USTCBusData {
        let url = URL(string: "\(staticURLPrefix)/bus_data_v3.json")
        let (data, _) = try await URLSession.shared.data(from: url!)
        return try JSONDecoder().decode(USTCBusData.self, from: data)
    }
}

extension ManagedDataSource<USTCBusData> {
    static let ustcBus = ManagedDataSource(
        local: ManagedLocalStorage("ustc_bus_v2"),
        remote: USTCBusDataDelegate.shared
    )
}

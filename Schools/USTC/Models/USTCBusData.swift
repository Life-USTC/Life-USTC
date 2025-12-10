//
//  USTC+BusDelegate.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

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
}

struct USTCRoute: Identifiable, Codable, Hashable {
    var id: Int
    var campuses: [USTCCampus]

    var description: String {
        let start = campuses.first?.name ?? ""
        let end = campuses.last?.name ?? ""
        return "\(start) - \(end)"
    }
}

struct USTCRouteSchedule: Identifiable, Codable, Equatable {
    var id: Int
    var route: USTCRoute
    var time: [[TimeString?]]

    var nextDeparture: [TimeString?]? {
        return time.filter { !$0.passed() }.first
    }
}

struct Message: Codable, Equatable {
    var message: String
    var url: String
}

struct USTCBusData: Codable, Equatable {
    var campuses: [USTCCampus]
    var routes: [USTCRoute]
    var weekday_routes: [USTCRouteSchedule]
    var weekend_routes: [USTCRouteSchedule]
    var message: Message?
}

extension USTCBusData {
    static func fetch() async throws -> USTCBusData {
        let url = URL(string: "\(Constants.ustcStaticURLPrefix)/bus_data_v3.json")
        let (data, _) = try await URLSession.shared.data(from: url!)
        return try JSONDecoder().decode(USTCBusData.self, from: data)
    }
}

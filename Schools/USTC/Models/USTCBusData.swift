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
    var saturday_routes: [USTCRouteSchedule]? = nil
    var sunday_routes: [USTCRouteSchedule]? = nil
}

extension USTCBusData {
    /// Fetch bus data, preferring server when authenticated, falling back to static JSON.
    static func fetch() async throws -> USTCBusData {
        if ServerClient.shared.isAuthenticated {
            do {
                return try await fetchFromServer()
            } catch {
                AppLogger.logger(for: "Bus").warning("Server bus fetch failed, falling back to static: \(error)")
            }
        }
        return try await fetchFromStatic()
    }

    /// Fetch from the legacy static server JSON.
    static func fetchFromStatic() async throws -> USTCBusData {
        let url = URL(string: "\(Constants.ustcStaticURLPrefix)/bus_data_v3.json")
        let (data, _) = try await URLSession.shared.data(from: url!)
        return try JSONDecoder().decode(USTCBusData.self, from: data)
    }

    /// Fetch the complete timetable, including all three service-day types.
    static func fetchFromServer() async throws -> USTCBusData {
        let response = try await ServerClient.shared.fetchBusSchedule()
        return USTCBusData(serverResponse: response)
    }

    init(serverResponse response: ServerBusResponse) {
        let campuses = response.campuses.map {
            USTCCampus(id: $0.id, name: $0.nameCn, latitude: $0.latitude, longitude: $0.longitude)
        }
        let routes = response.routes.map { route in
            USTCRoute(id: route.id, campuses: route.stops.sorted { $0.stopOrder < $1.stopOrder }.map {
                let campus = $0.campus
                return USTCCampus(id: campus.id, name: campus.nameCn, latitude: campus.latitude, longitude: campus.longitude)
            })
        }

        func schedules(for day: ServerBusDayType) -> [USTCRouteSchedule] {
            zip(response.routes, routes).map { serverRoute, route in
                let stopOrders = serverRoute.stops.map(\.stopOrder).sorted()
                let times = response.trips.filter { $0.routeId == route.id && $0.dayType == day }
                    .sorted { $0.position < $1.position }
                    .map { trip in
                        stopOrders.map { order in trip.stopTimes.first { $0.stopOrder == order }?.time }
                    }
                return USTCRouteSchedule(id: route.id, route: route, time: times)
            }
        }

        self.init(
            campuses: campuses,
            routes: routes,
            weekday_routes: schedules(for: .weekday),
            weekend_routes: [],
            message: response.notice.map { Message(message: $0.message ?? "", url: $0.url ?? "") },
            saturday_routes: schedules(for: .saturday),
            sunday_routes: schedules(for: .sunday)
        )
    }

    func schedules(for day: ServerBusDayType) -> [USTCRouteSchedule] {
        switch day {
        case .weekday: weekday_routes
        // The existing static JSON has one shared weekend timetable.
        case .saturday: saturday_routes ?? weekend_routes
        case .sunday: sunday_routes ?? weekend_routes
        }
    }
}

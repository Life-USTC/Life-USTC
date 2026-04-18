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

    /// Fetch from the Life@USTC server API and translate into USTCBusData format.
    static func fetchFromServer() async throws -> USTCBusData {
        let response: ServerBusResponse = try await ServerClient.shared.request(
            .busSchedule(originCampusId: nil, destinationCampusId: nil, dayType: nil, limit: nil)
        )

        // Map campuses
        let campuses = (response.campuses ?? []).map { sc in
            USTCCampus(id: sc.id, name: sc.nameCn, latitude: 0, longitude: 0)
        }
        let campusMap = Dictionary(uniqueKeysWithValues: campuses.map { ($0.id, $0) })

        // Map routes
        let routes = (response.routes ?? []).map { sr in
            let routeCampuses = (sr.stops ?? [])
                .sorted(by: { $0.stopOrder < $1.stopOrder })
                .compactMap { stop -> USTCCampus? in
                    guard let campus = stop.campus else { return nil }
                    return campusMap[campus.id] ?? USTCCampus(id: campus.id, name: campus.nameCn, latitude: 0, longitude: 0)
                }
            return USTCRoute(id: sr.id, campuses: routeCampuses)
        }
        let routeMap = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0) })

        // Build schedule matrices from matches
        // Group trips by route + dayType → build time matrix
        var weekdaySchedules: [Int: [[TimeString?]]] = [:]
        var weekendSchedules: [Int: [[TimeString?]]] = [:]

        for match in (response.matches ?? []) {
            guard let route = match.route else { continue }
            let trips = match.upcomingTrips ?? (match.nextTrip.map { [$0] } ?? [])

            for trip in trips {
                let isWeekend = trip.dayType == "weekend" || trip.dayType == "holiday"
                let routeId = route.id

                // Build time row: one time per stop
                let stopTimes = (trip.stopTimes ?? [])
                    .sorted(by: { $0.stopOrder < $1.stopOrder })
                    .map { $0.time as TimeString? }

                if isWeekend {
                    weekendSchedules[routeId, default: []].append(stopTimes)
                } else {
                    weekdaySchedules[routeId, default: []].append(stopTimes)
                }
            }
        }

        // Convert to USTCRouteSchedule arrays
        func makeSchedules(_ dict: [Int: [[TimeString?]]]) -> [USTCRouteSchedule] {
            dict.compactMap { (routeId, times) -> USTCRouteSchedule? in
                guard let route = routeMap[routeId] else { return nil }
                let sorted = times.sorted { a, b in
                    let aMin = a.compactMap({ $0?.minutesSinceMidnight }).first ?? 0
                    let bMin = b.compactMap({ $0?.minutesSinceMidnight }).first ?? 0
                    return aMin < bMin
                }
                return USTCRouteSchedule(id: routeId, route: route, time: sorted)
            }
        }

        let message = response.notice.map { Message(message: $0.message ?? "", url: $0.url ?? "") }

        return USTCBusData(
            campuses: campuses,
            routes: routes,
            weekday_routes: makeSchedules(weekdaySchedules),
            weekend_routes: makeSchedules(weekendSchedules),
            message: message
        )
    }
}

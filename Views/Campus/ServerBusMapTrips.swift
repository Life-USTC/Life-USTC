import CoreLocation
import Foundation

struct ServerBusActiveTrip: Identifiable {
    enum Status: Equatable { case enRoute, departingSoon }
    let id: Int
    let routeID: Int
    let status: Status
    let fromStopOrder: Int?
    let toStopOrder: Int?
    let progress: Double?

    static func trips(_ trips: [ServerBusTrip], at date: Date) -> [Self] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let weekday = calendar.component(.weekday, from: date)
        let day: ServerBusDayType = weekday == 1 ? .sunday : weekday == 7 ? .saturday : .weekday
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return trips.filter { $0.dayType == day }.compactMap { trip in
            let stops = trip.stopTimes.sorted { $0.stopOrder < $1.stopOrder }
            let known = stops.compactMap(\.minutesSinceMidnight)
            guard let first = known.first, let last = known.last else { return nil }
            if minutes >= first, minutes <= last {
                let segment = zip(stops, stops.dropFirst()).first { before, after in
                    guard let start = before.minutesSinceMidnight, let end = after.minutesSinceMidnight else { return false }
                    return minutes >= start && minutes <= end
                }
                let progress: Double?
                if let segment, let start = segment.0.minutesSinceMidnight, let end = segment.1.minutesSinceMidnight {
                    progress = end > start ? (Double(minutes - start) / Double(end - start) * 100).rounded() / 100 : 0
                } else { progress = nil }
                return Self(id: trip.id, routeID: trip.routeId, status: .enRoute,
                            fromStopOrder: segment?.0.stopOrder, toStopOrder: segment?.1.stopOrder, progress: progress)
            }
            guard first > minutes, first <= minutes + 60 else { return nil }
            return Self(id: trip.id, routeID: trip.routeId, status: .departingSoon,
                        fromStopOrder: nil, toStopOrder: nil, progress: nil)
        }
    }

    func coordinate(in route: ServerBusRoute) -> CLLocationCoordinate2D? {
        let stops = route.stops.sorted { $0.stopOrder < $1.stopOrder }
        if status == .departingSoon, let campus = stops.first?.campus {
            return .init(latitude: campus.latitude, longitude: campus.longitude)
        }
        guard let from = stops.first(where: { $0.stopOrder == fromStopOrder })?.campus,
              let to = stops.first(where: { $0.stopOrder == toStopOrder })?.campus,
              let progress else { return nil }
        // Keep the glyph clear of station labels, as the server map does.
        let fraction = min(0.85, max(0.15, progress))
        return .init(latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                     longitude: from.longitude + (to.longitude - from.longitude) * fraction)
    }
}

struct ServerRecentBusRoute: Codable, Equatable {
    let origin: Int
    let destination: Int

    func isTraversable(in routes: [ServerBusRoute]) -> Bool {
        routes.contains { route in
            let stops = route.stops.sorted { $0.stopOrder < $1.stopOrder }
            guard let from = stops.firstIndex(where: { $0.campus.id == origin }),
                  let to = stops.firstIndex(where: { $0.campus.id == destination }) else { return false }
            return to > from
        }
    }
}

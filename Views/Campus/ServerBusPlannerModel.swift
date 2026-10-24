import SwiftUI

struct ServerBusStopClock: Equatable {
    let minutes: Int
    let estimated: Bool
    var text: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    /// The server permits estimates only between two known, same-day stop times.
    static func at(campusID: Int, trip: ServerBusTrip) -> Self? {
        let stops = trip.stopTimes.sorted { $0.stopOrder < $1.stopOrder }
        guard let index = stops.firstIndex(where: { $0.campusId == campusID }) else { return nil }
        if let minutes = stops[index].minutesSinceMidnight { return .init(minutes: minutes, estimated: false) }
        let before = stops[..<index].reversed().compactMap(\.minutesSinceMidnight).first
        let after = stops.dropFirst(index + 1).compactMap(\.minutesSinceMidnight).first
        guard let before, let after, before <= after else { return nil }
        return .init(minutes: (before + after + 1) / 2, estimated: true)
    }
}

@MainActor @Observable
final class ServerBusPlannerModel {
    private let client: ServerClient
    private let defaults: UserDefaults
    static let recentRouteKey = "serverBusRecentRoute"
    private var revision: UUID?
    private var preferencesLoaded = false
    private var selectionChanged = false
    private(set) var timetable: ServerCampusBusTimetable?
    private(set) var routeResult: ServerBusRouteSearchResponse?
    private(set) var next: ServerBusNextResponse?
    private(set) var isLoading = false
    private(set) var isLoadingDepartures = false
    private(set) var isSavingPreference = false
    private(set) var error: String?
    private(set) var departureError: String?
    private(set) var preferenceError: String?
    private(set) var origin: Int?
    private(set) var destination: Int?
    private(set) var showDeparted = false
    var dayType = "auto"
    var versionKey: String?

    init(client: ServerClient = .shared, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    var canSavePreference: Bool { client.isAuthenticated && revision == client.sessionRevision && preferencesLoaded && selectionChanged && !isSavingPreference }
    var queryKey: String { "\(origin ?? 0):\(destination ?? 0):\(dayType):\(showDeparted):\(versionKey ?? "current")" }
    var selectedDayType: ServerBusDayType {
        if let explicit = ServerBusDayType(rawValue: dayType) { return explicit }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        switch calendar.component(.weekday, from: next?.atTime ?? Date()) {
        case 1: return .sunday
        case 7: return .saturday
        default: return .weekday
        }
    }

    func selectOrigin(_ id: Int?) { origin = id; selectionChanged = true; saveRecentRoute() }
    func selectDestination(_ id: Int?) { destination = id; selectionChanged = true; saveRecentRoute() }
    func setShowDeparted(_ value: Bool) { showDeparted = value; selectionChanged = true }
    func reverse() { (origin, destination) = (destination, origin); selectionChanged = true; saveRecentRoute() }

    private func saveRecentRoute() {
        guard !client.isAuthenticated, let origin, let destination,
              let routes = timetable?.routes else { return }
        let route = ServerRecentBusRoute(origin: origin, destination: destination)
        guard route.isTraversable(in: routes), let data = try? JSONEncoder().encode(route) else { return }
        defaults.set(data, forKey: Self.recentRouteKey)
    }

    func load() async {
        if revision != client.sessionRevision {
            origin = nil
            destination = nil
            showDeparted = false
            preferencesLoaded = false
            selectionChanged = false
            preferenceError = nil
        }
        revision = client.sessionRevision
        let expectedRevision = client.sessionRevision
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let value = try await client.fetchCampusBusTimetable(versionKey: versionKey)
            guard expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            timetable = value
            if !value.campuses.contains(where: { $0.id == origin }) { origin = value.routes.first?.stops.first?.campus.id }
            if !value.campuses.contains(where: { $0.id == destination }) { destination = value.routes.first?.stops.last?.campus.id }
            if !selectionChanged, !preferencesLoaded, let data = defaults.data(forKey: Self.recentRouteKey),
               let recent = try? JSONDecoder().decode(ServerRecentBusRoute.self, from: data),
               recent.isTraversable(in: value.routes) {
                origin = recent.origin
                destination = recent.destination
            }
        } catch is CancellationError { return }
        catch { if expectedRevision == client.sessionRevision { self.error = error.localizedDescription } }
        if !preferencesLoaded { await loadPreference() }
    }

    func loadPreference() async {
        guard client.isAuthenticated else { return }
        let expectedRevision = client.sessionRevision
        preferenceError = nil
        do {
            let preference = try await client.fetchBusPreference()
            guard revision == expectedRevision, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            preferencesLoaded = true
            if !selectionChanged {
                if let id = preference.preferredOriginCampusId, timetable?.campuses.contains(where: { $0.id == id }) == true { origin = id }
                if let id = preference.preferredDestinationCampusId, timetable?.campuses.contains(where: { $0.id == id }) == true { destination = id }
                showDeparted = preference.showDepartedTrips
            }
        } catch is CancellationError { return }
        catch { if expectedRevision == client.sessionRevision { preferenceError = error.localizedDescription } }
    }

    func savePreference() async {
        guard canSavePreference, let revision else { return }
        let preference = ServerBusPreference(preferredOriginCampusId: origin, preferredDestinationCampusId: destination,
                                             showDepartedTrips: showDeparted)
        isSavingPreference = true
        preferenceError = nil
        defer { isSavingPreference = false }
        do {
            _ = try await client.saveBusPreference(preference, expectedRevision: revision)
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            selectionChanged = false
        } catch is CancellationError { return }
        catch { if revision == client.sessionRevision { preferenceError = error.localizedDescription } }
    }

    func refreshDepartures(locale: String) async {
        let key = queryKey
        guard let origin, let destination, origin != destination else { next = nil; routeResult = nil; return }
        let expectedRevision = client.sessionRevision
        isLoadingDepartures = true
        departureError = nil
        next = nil
        routeResult = nil
        defer { if key == queryKey { isLoadingDepartures = false } }
        do {
            async let routes = client.searchBusRoutes(origin: origin, destination: destination, versionKey: versionKey, locale: locale)
            async let departures = client.fetchNextBuses(.init(originCampusId: origin, destinationCampusId: destination,
                                                               dayType: dayType, includeDeparted: showDeparted,
                                                               versionKey: versionKey, locale: locale))
            let response = try await (routes, departures)
            guard key == queryKey, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            routeResult = response.0
            next = response.1
        } catch is CancellationError { return }
        catch { if key == queryKey, expectedRevision == client.sessionRevision { departureError = error.localizedDescription } }
    }

    func trips(for routeID: Int) -> [ServerBusTrip] {
        guard let origin else { return [] }
        let now = referenceMinutes
        return (timetable?.trips ?? []).filter {
            guard $0.routeId == routeID, $0.dayType == selectedDayType else { return false }
            guard !showDeparted, let clock = ServerBusStopClock.at(campusID: origin, trip: $0) else { return true }
            return clock.minutes >= now
        }.sorted {
            let left = ServerBusStopClock.at(campusID: origin, trip: $0)?.minutes ?? Int.max
            let right = ServerBusStopClock.at(campusID: origin, trip: $1)?.minutes ?? Int.max
            return left == right ? $0.position < $1.position : left < right
        }
    }

    var orderedRoutes: [ServerBusRouteSearchResponse.Route] {
        (routeResult?.routes ?? []).sorted {
            let left = nextBoardingMinutes(routeID: $0.id)
            let right = nextBoardingMinutes(routeID: $1.id)
            return left == right ? $0.id < $1.id : left < right
        }
    }

    private var referenceMinutes: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = next?.atTime ?? Date()
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func nextBoardingMinutes(routeID: Int) -> Int {
        guard let origin else { return Int.max }
        return trips(for: routeID).compactMap { ServerBusStopClock.at(campusID: origin, trip: $0)?.minutes }
            .filter { $0 >= referenceMinutes }.min() ?? Int.max
    }
}

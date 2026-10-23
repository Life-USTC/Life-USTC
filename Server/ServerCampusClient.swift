import Foundation

extension ServerClient {
    func fetchCampusLinks(locale: String) async throws -> [ServerCampusLink] {
        let response: ServerCampusLinksResponse = try await request(.campusLinks(locale: locale))
        return response.links
    }

    func fetchLinkPins() async throws -> ServerLinkPinsResponse {
        try await request(.linkPins)
    }

    func setLinkPinned(slug: String, pinned: Bool, expectedRevision: UUID) async throws -> ServerLinkPinsResponse {
        try await request(.setLinkPins(.init(items: [.init(slug: slug, action: pinned ? "pin" : "unpin")])),
                          expectedRevision: expectedRevision)
    }

    func fetchCampusBusTimetable(versionKey: String? = nil) async throws -> ServerCampusBusTimetable {
        try await request(.busSchedule(versionKey: versionKey))
    }

    func searchBusRoutes(origin: Int?, destination: Int?, versionKey: String? = nil, locale: String) async throws -> ServerBusRouteSearchResponse {
        try await request(.busRoutes(origin: origin, destination: destination, versionKey: versionKey, locale: locale))
    }

    func fetchNextBuses(_ query: ServerBusNextQuery) async throws -> ServerBusNextResponse {
        try await request(.busNext(query))
    }

    func fetchBusPreference() async throws -> ServerBusPreference {
        let response: ServerBusPreferenceResponse = try await request(.busPreferences)
        return response.preference
    }

    func saveBusPreference(_ preference: ServerBusPreference, expectedRevision: UUID) async throws -> ServerBusPreference {
        let response: ServerBusPreferenceResponse = try await request(.setBusPreferences(preference), expectedRevision: expectedRevision)
        return response.preference
    }

    func fetchWeather(location: ServerWeatherLocation) async throws -> ServerWeatherSnapshot {
        try await request(.campusWeather(location))
    }

    func fetchRoomMap(code: String) async throws -> ServerRoomMap {
        try await request(.roomMap(code: code))
    }

    func searchCampus(query: String, locale: String) async throws -> ServerGlobalSearchResponse {
        try await request(.campusSearch(query: query, locale: locale))
    }
}

import Foundation

struct ServerCampusLink: Decodable, Identifiable {
    let slug: String
    let title: String
    let url: String
    let description: String
    let titlePinyin: String
    let descriptionPinyin: String
    let category: String
    let icon: String
    let group: String
    var id: String { slug }

    func matches(_ query: String) -> Bool {
        let searchable = [title, description, url, titlePinyin, descriptionPinyin].joined(separator: " ").lowercased()
        return query.lowercased().split(whereSeparator: \.isWhitespace).allSatisfy { searchable.contains($0) }
    }
}

struct ServerCampusLinksResponse: Decodable { let links: [ServerCampusLink] }

struct ServerLinkPinsResponse: Decodable {
    let pinnedSlugs: [String]
    let maxPinnedLinks: Int
    let error: String?
}

struct ServerLinkPinBatchRequest: Encodable {
    struct Item: Encodable {
        let slug: String
        let action: String
    }
    let items: [Item]
}

struct ServerBusPreference: Codable, Equatable {
    var preferredOriginCampusId: Int?
    var preferredDestinationCampusId: Int?
    var showDepartedTrips: Bool

    enum CodingKeys: String, CodingKey {
        case preferredOriginCampusId, preferredDestinationCampusId, showDepartedTrips
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferredOriginCampusId, forKey: .preferredOriginCampusId)
        try container.encode(preferredDestinationCampusId, forKey: .preferredDestinationCampusId)
        try container.encode(showDepartedTrips, forKey: .showDepartedTrips)
    }
}

struct ServerBusPreferenceResponse: Decodable { let preference: ServerBusPreference }

struct ServerCampusBusTimetable: Decodable {
    struct Version: Decodable, Identifiable {
        let id: Int
        let key: String
        let title: String
        let effectiveFrom: Date?
        let effectiveUntil: Date?
        let importedAt: Date
        let notice: ServerBusNotice?
    }
    let locale: String
    let fetchedAt: Date
    let version: Version?
    let availableVersions: [Version]
    let campuses: [ServerBusCampus]
    let routes: [ServerBusRoute]
    let trips: [ServerBusTrip]
    let notice: ServerBusNotice?
}

struct ServerBusRouteSummary: Decodable, Identifiable {
    let id: Int
    let nameCn: String
    let nameEn: String?
    let descriptionPrimary: String
    let descriptionSecondary: String?
}

struct ServerBusRouteSearchResponse: Decodable {
    struct Route: Decodable, Identifiable {
        let id: Int
        let nameCn: String
        let nameEn: String?
        let descriptionPrimary: String
        let descriptionSecondary: String?
        let originCampus: ServerBusCampus?
        let destinationCampus: ServerBusCampus?
        let stopCount: Int
        let weekdayTrips: Int
        let saturdayTrips: Int
        let sundayTrips: Int
        let stops: [ServerBusStop]
    }
    let originCampus: ServerBusCampus?
    let destinationCampus: ServerBusCampus?
    let total: Int
    let routes: [Route]
}

struct ServerBusDeparture: Decodable, Identifiable {
    let tripId: Int
    let routeId: Int
    let route: ServerBusRouteSummary
    let originCampus: ServerBusCampus?
    let destinationCampus: ServerBusCampus?
    let departureTime: String?
    let arrivalTime: String?
    let departureEstimated: Bool
    let arrivalEstimated: Bool
    let minutesUntilDeparture: Int?
    let dayType: ServerBusDayType
    let status: String
    var id: Int { tripId }
}

struct ServerBusNextResponse: Decodable {
    let originCampus: ServerBusCampus?
    let destinationCampus: ServerBusCampus?
    let atTime: Date
    let dayType: ServerBusDayType
    let totalRoutes: Int
    let departures: [ServerBusDeparture]
    let nextAvailableDeparture: ServerBusDeparture?
    let message: String?
}

struct ServerBusNextQuery {
    var originCampusId: Int
    var destinationCampusId: Int
    var dayType: String = "auto"
    var includeDeparted = false
    var limit = 50
    var versionKey: String?
    var atTime: String?
    var locale: String
}

enum ServerWeatherLocation: String, CaseIterable, Codable, Identifiable {
    case main = "ustc-main"
    case gaoxin = "ustc-gaoxin"
    var id: String { rawValue }
}

struct ServerWeatherSnapshot: Decodable {
    struct Location: Decodable {
        let key: ServerWeatherLocation
        let name: String
        let adcode: String
    }
    struct Condition: Decodable { let text: String; let icon: String }
    struct Current: Decodable {
        let source: String?
        let observedAt: Date?
        let temperature: Double?
        let feelsLike: Double?
        let humidity: Double?
        let windDirection: String?
        let windSpeed: Double?
        let pressure: Double?
        let visibility: Double?
        let condition: Condition
    }
    struct Hour: Decodable, Identifiable {
        let at: Date
        let temperature: Double
        let condition: Condition?
        let precipitationProbability: Double?
        let precipitationAmount: Double?
        var id: Date { at }
    }
    struct Day: Decodable, Identifiable {
        let date: String
        let temperatureHigh: Double
        let temperatureLow: Double
        let condition: Condition?
        var id: String { date }
    }
    struct Alert: Decodable {
        let title: String
        let level: String?
        let content: String?
        let issuedAt: Date?
    }
    let location: Location
    let fetchedAt: Date
    let providers: [String]
    let current: Current
    let hourly: [Hour]
    let daily: [Day]
    let alerts: [Alert]
}

struct ServerRoomMap: Decodable {
    enum Status: String, Decodable { case highlighted, overview, unavailable }
    let code: String
    let building: String?
    let floor: String?
    let status: Status
    let imageUrl: String?
    let sourceImageUrl: String?
}

struct ServerGlobalSearchResponse: Decodable {
    struct Item: Decodable, Identifiable {
        let id: String
        let title: String
        let description: String?
        let code: String?
        let href: String
        let external: Bool?
    }
    struct Group: Decodable, Identifiable {
        let type: String
        let items: [Item]
        var id: String { type }
    }
    let query: String
    let groups: [Group]
}

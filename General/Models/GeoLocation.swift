import Foundation
import SwiftyJSON

struct GeoLocation {
    var id: String { name }
    var name: String
    var latitude: Double
    var longitude: Double

    init(
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension [GeoLocation] {
    static func refresh() async throws -> Self {
        let (data, _) = try await URLSession.shared.data(from: SchoolSystem.current.geoLocationURL)
        let json = try JSON(data: data)

        return json["locations"].arrayValue
            .map {
                GeoLocation(
                    name: $0["name"].stringValue,
                    latitude: $0["latitude"].doubleValue,
                    longitude: $0["longitude"].doubleValue
                )
            }
    }
}

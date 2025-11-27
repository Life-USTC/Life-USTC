import Foundation
import SwiftData
import SwiftyJSON

enum GeoRepository {
    static func refresh() async throws {
        let (data, _) = try await URLSession.shared.data(from: SchoolSystem.current.geoLocationDataURL)
        let context = SwiftDataStack.context
        try context.cacheJSON(key: "geo_location", data: data)
    }

    static func get() throws -> [GeoLocationData]? {
        let context = SwiftDataStack.context
        guard let data = try context.getCachedJSON(key: "geo_location") else { return nil }
        let json = try JSON(data: data)
        return json["locations"].arrayValue
            .map {
                GeoLocationData(
                    name: $0["name"].stringValue,
                    latitude: $0["latitude"].doubleValue,
                    longitude: $0["longitude"].doubleValue
                )
            }
    }
}

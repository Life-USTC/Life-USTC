//
//  GeoLocationData.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftyJSON

/// Geographic location data for campus buildings/locations
struct GeoLocationData: Codable, Equatable, ExampleDataProtocol {
    var name: String
    var latitude: Double
    var longitude: Double

    static let example = GeoLocationData(
        name: "东区体育中心",
        latitude: 31.835946350451458,
        longitude: 117.2660348207498
    )
}

/// Delegate for fetching geographic location data
class GeoLocationDelegate: ManagedRemoteUpdateProtocol<[GeoLocationData]> {
    static let shared = GeoLocationDelegate()

    override func refresh() async throws -> [GeoLocationData] {
        let url = SchoolExport.shared.geoLocationDataURL

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return json["locations"].arrayValue
            .map {
                let name = $0["name"].stringValue
                let latitude = $0["latitude"].doubleValue
                let longitude = $0["longitude"].doubleValue
                return GeoLocationData(
                    name: name,
                    latitude: latitude,
                    longitude: longitude
                )
            }
    }
}

extension ManagedDataSource<[GeoLocationData]> {
    static let geoLocation = ManagedDataSource(
        local: ManagedLocalStorage("geoLocation"),
        remote: GeoLocationDelegate.shared
    )
}

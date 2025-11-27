//
//  GeoLocationData.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftyJSON

struct GeoLocationData: Identifiable, Codable {
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

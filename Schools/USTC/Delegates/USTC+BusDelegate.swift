//
//  USTC+BusDelegate.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import Foundation
import SwiftUI
import SwiftyJSON

struct USTCCampus: Identifiable, Codable, Hashable {
    var id: Int
    var name: String

    var latitude: Double
    var longitude: Double

    static let example = USTCCampus(
        id: 1,
        name: "东区",
        latitude: 100,
        longitude: 30
    )
}

//typealias USTCRoute = [USTCCampus]
struct USTCRoute: Identifiable, Codable, Hashable {
    var id: Int
    var campuses: [USTCCampus]

    static let example = USTCRoute(
        id: 1,
        campuses: [.example, .example]
    )
}

struct USTCRouteSchedule: Identifiable, Codable, Equatable {
    var id: Int
    var route: USTCRoute
    var time: [[String?]]

    static let example = USTCRouteSchedule(
        id: 1,
        route: .example,
        time: [
            ["07:50", "08:10"]
        ]
    )
}

struct Message: Codable {
    var message: String
    var url: String
}

struct USTCBusData: ExampleDataProtocol, Codable {
    var campuses: [USTCCampus]

    var routes: [USTCRoute]

    var weekday_routes: [USTCRouteSchedule]
    var weekend_routes: [USTCRouteSchedule]

    var message: Message?

    static let example = USTCBusData(
        campuses: [.example],
        routes: [.example],
        weekday_routes: [.example],
        weekend_routes: [.example]
    )
}

class USTCBusDataDelegate: ManagedRemoteUpdateProtocol<USTCBusData> {
    static let shared = USTCBusDataDelegate()

    override func refresh() async throws -> USTCBusData {
        let url = URL(string: "\(staticURLPrefix)/bus_data_v3.json")
        let (data, _) = try await URLSession.shared.data(from: url!)
        //        let path = Bundle.main.path(forResource: "ustc_bus_data_v2", ofType: "json")
        //        let url = URL(fileURLWithPath: path!)
        //        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(USTCBusData.self, from: data)
    }
}

extension ManagedDataSource<USTCBusData> {
    static let ustcBus = ManagedDataSource(
        local: ManagedLocalStorage("ustc_bus_v2"),
        remote: USTCBusDataDelegate.shared
    )
}

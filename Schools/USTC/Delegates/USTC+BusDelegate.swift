//
//  USTC+BusDelegate.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import Foundation
import SwiftUI
import SwiftyJSON

class USTCBusDelegate: ManagedRemoteUpdateProtocol<[Bus]> {
    static let shared = USTCBusDelegate()
    @AppStorage("ustcBusSelectedDate") var date: Date = .now

    override func refresh() async throws -> [Bus] {
        var result: [Bus] = []
        let calendar = Calendar(identifier: .gregorian)
        var from: String
        var to: String
        var startTime: Date
        if let path = Bundle.main.path(forResource: "ustc_bus_data", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let jsonData = try JSON(data: data)
                for (id, subJson): (String, JSON) in jsonData["buses"] {
                    print(id)
                    from = subJson["from"].stringValue
                    to = subJson["to"].stringValue
                    startTime = calendar.date(
                        from: DateComponents(
                            calendar: calendar,
                            timeZone: TimeZone(identifier: "Asia/Shanghai"),
                            hour: Int(subJson["startHour"].stringValue),
                            minute: Int(subJson["startMin"].stringValue)
                        )
                    )!

                    result.append(
                        Bus(
                            id: Int(id)!,
                            from: from,
                            to: to,
                            startTime: startTime,
                            timeTable: subJson["timeTable"].arrayValue.map { Int($0.stringValue)! },
                            type: subJson["type"].stringValue,
                            stationNum: Int(subJson["stationNum"].stringValue)!
                        )
                    )
                }
            } catch {
                print("Error reading JSON file: \(error)")
            }
        }
        return result
    }
}

extension ManagedDataSource<[Bus]> {
    static let bus = ManagedDataSource(
        local: ManagedLocalStorage("ustc_bus"),
        remote: USTCBusDelegate.shared
    )
}

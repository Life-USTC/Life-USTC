//
//  Bus.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import Foundation

enum BusType {
    case weekend, weekday
}

struct Bus: Codable, Identifiable {
    var id: Int
    var from: String
    var to: String
    var startTime: Date
    var timeTable: [Int]
    var type: String
    var stationNum: Int
}

extension Bus: ExampleDataProtocol {
    static var example: Bus {
        let calendar = Calendar(identifier: .gregorian)
        let startTime = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: TimeZone(identifier: "Asia/Shanghai"),
                hour: 08,
                minute: 00
            )
        )
        return Bus(
            id: 1,
            from: "东区",
            to: "高新",
            startTime: startTime!,
            timeTable: [5, 0, 40],
            type: "weekday",
            stationNum: 4
        )
    }

}

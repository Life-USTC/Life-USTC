//
//  USTC+BusDelegate.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import Foundation
import SwiftUI
import SwiftyJSON

class USTCBusDelegate: ManagedRemoteUpdateProtocol {
    static let shared = USTCBusDelegate()

    @LoginClient(.ustcCatalog) var catalogClient: UstcCatalogClient
    @AppStorage("ustcBusSelectedDate") var date: Date = .now


    func refresh() async throws -> [Bus] {
        var result: [Bus] = []
        
        /*
         Bus(
             route: "东区-高新",
             startTime: startTime!,
             timeTable: [5, 0, 40],
             type: "weekday",
             stationNum: 4,
             reverse: true
         )
         */
        var id = 1
        var calendar = Calendar(identifier: .gregorian)
        var from = "东区"
        var to = "高新"
        var type = "weekday"
        var stationNum = 4
        var startTime = calendar.date(from: DateComponents (
            calendar: calendar,
            timeZone: TimeZone(identifier: "Asia/Shanghai"),
            hour: 08,
            minute: 00
        ))
        var timeTable = [10, 0, 50]
        result.append(
            Bus (
                id: id,
                from: from,
                to: to,
                startTime: startTime!,
                timeTable: timeTable,
                type: type,
                stationNum: stationNum
            )
        )
        
        return result
    }
}

extension ManagedDataSource<[Bus]> {
    static let bus = ManagedDataSource(
        local: ManagedLocalStorage("ustc_bus"),
        remote: USTCBusDelegate.shared
    )
}

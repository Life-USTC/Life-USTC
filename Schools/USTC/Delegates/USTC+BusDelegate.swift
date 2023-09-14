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
        let calendar = Calendar(identifier: .gregorian)
        var from = "东区"
        var to = "高新"
        var type = "weekday"
        var stationNum = 4
        var startTime = calendar.date(from: DateComponents (
            calendar: calendar,
            timeZone: TimeZone(identifier: "Asia/Shanghai"),
            hour: 6,
            minute: 50
        ))
        var timeTable = [10, 0, 50]
        result.append(Bus (id: 1, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 70, to: startTime!)!
        result.append(Bus (id: 2, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 280, to: startTime!)!
        timeTable = [10, 0, 40]
        result.append(Bus (id: 3, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 110, to: startTime!)!
        timeTable = [10, 0, 45]
        result.append(Bus (id: 4, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 235, to: startTime!)!
        timeTable = [10, 0, 50]
        result.append(Bus (id: 5, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 175, to: startTime!)!
        timeTable = [10, 0, 30]
        result.append(Bus (id: 6, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(byAdding: .minute, value: 45, to: startTime!)!
        timeTable = [10, 0, 45]
        result.append(Bus (id: 7, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        from = "高新"
        to = "东区"
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 6, minute: 40))
        timeTable = [5, 0, 40]
        result.append(Bus (id: 8, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 8, minute: 00))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 9, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 9, minute: 35))
        timeTable = [5, 0, 40]
        result.append(Bus (id: 10, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 12, minute: 40))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 11, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 14, minute: 30))
        timeTable = [5, 0, 50]
        result.append(Bus (id: 12, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 18, minute: 25))
        timeTable = [5, 0, 50]
        result.append(Bus (id: 13, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 22, minute: 05))
        timeTable = [5, 0, 40]
        result.append(Bus (id: 14, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        from = "东区"
        to = "高新"
        type = "weekend"
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 07, minute: 00))
        timeTable = [10, 0, 40]
        result.append(Bus (id: 15, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 12, minute: 40))
        timeTable = [10, 0, 40]
        result.append(Bus (id: 16, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 18, minute: 30))
        timeTable = [10, 0, 50]
        result.append(Bus (id: 17, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 21, minute: 50))
        timeTable = [10, 0, 50]
        result.append(Bus (id: 18, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        from = "高新"
        to = "东区"
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 08, minute: 00))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 19, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 13, minute: 40))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 20, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 16, minute: 00))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 21, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        startTime = calendar.date(from: DateComponents (calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai"), hour: 21, minute: 50))
        timeTable = [5, 0, 45]
        result.append(Bus (id: 22, from: from, to: to, startTime: startTime!, timeTable: timeTable, type: type, stationNum: stationNum))
        
        
        return result
    }
}

extension ManagedDataSource<[Bus]> {
    static let bus = ManagedDataSource(
        local: ManagedLocalStorage("ustc_bus"),
        remote: USTCBusDelegate.shared
    )
}

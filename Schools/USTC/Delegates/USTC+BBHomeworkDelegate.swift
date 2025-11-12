//
//  USTC+BBHomeworkDelegate.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation
import SwiftyJSON

private func decodeDate(from raw: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    return dateFormatter.date(from: raw)
}

class USTCBBHomeworkDelegate: ManagedRemoteUpdateProtocol<[Homework]> {
    static let shared = USTCBBHomeworkDelegate()

    @LoginClient(.ustcBlackboard) var blackboardClient
    var session: URLSession = .shared

    override func refresh() async throws -> [Homework] {
        if try await !_blackboardClient.requireLogin() {
            throw BaseError.runtimeError("UstcBlackboard Not logined")
        }

        let (data, _) = try await session.data(
            from: URL(
                string:
                    "https://www.bb.ustc.edu.cn/webapps/calendar/calendarData/selectedCalendarEvents?start=&end=&course_id=&mode=personal?start=&end=&course_id=&mode=personal"
            )!
        )
        let cache = try JSON(data: data)

        return
            cache.map { _, homeworkJSON in
                if let dueDate = decodeDate(from: homeworkJSON["endDate"].stringValue) {
                    return Homework(
                        title: homeworkJSON["title"].stringValue,
                        courseName: homeworkJSON["calendarNameLocalizable"]["rawValue"].stringValue,
                        dueDate: dueDate
                    )
                }
                return nil
            }
            .compactMap { $0 }
    }
}

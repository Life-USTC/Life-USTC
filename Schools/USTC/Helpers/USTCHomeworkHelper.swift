//
//  USTC+BBHomeworkDelegate.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation
import SwiftyJSON

extension USTCSchool {
    @MainActor
    static func updateHomework() async throws {
        func decodeDate(from raw: String) -> Date? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            return dateFormatter.date(from: raw)
        }

        @LoginClient(.ustcBlackboard) var blackboardClient

        if try await !_blackboardClient.requireLogin() {
            throw BaseError.runtimeError("UstcBlackboard Not logined")
        }

        let (data, _) = try await URLSession.shared.data(
            from: URL(
                string:
                    "https://www.bb.ustc.edu.cn/webapps/calendar/calendarData/selectedCalendarEvents?start=&end=&course_id=&mode=personal?start=&end=&course_id=&mode=personal"
            )!
        )
        let cache = try JSON(data: data)

        for homeworkJSON in cache.arrayValue {
            guard let dueDate = decodeDate(from: homeworkJSON["endDate"].stringValue) else {
                continue
            }
            let homework = Homework(
                title: homeworkJSON["title"].stringValue,
                courseName: homeworkJSON["calendarNameLocalizable"]["rawValue"].stringValue,
                dueDate: dueDate
            )

            SwiftDataStack.modelContext.insert(homework)
        }
    }
}

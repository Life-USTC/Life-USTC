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
        if SwiftDataStack.isPresentingDemo { return }

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

        // remove all old homework entries
        try! SwiftDataStack.modelContext.delete(model: Homework.self)

        for homeworkJSON in cache.arrayValue {
            guard let dueDate = decodeDate(from: homeworkJSON["endDate"].stringValue) else {
                continue
            }

            let title = homeworkJSON["title"].stringValue
            let courseName = homeworkJSON["calendarNameLocalizable"]["rawValue"].stringValue

            try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<Homework> { $0.title == title && $0.courseName == courseName },
                update: { homework in
                    homework.dueDate = dueDate
                },
                create: {
                    Homework(
                        title: title,
                        courseName: courseName,
                        dueDate: dueDate
                    )
                }
            )
        }
    }
}

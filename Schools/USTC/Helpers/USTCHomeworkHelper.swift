//
//  USTC+BBHomeworkDelegate.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import Foundation

extension USTCSchool {
    @MainActor
    static func updateHomework() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        @LoginClient(.ustcBlackboard) var blackboardClient

        if try await !_blackboardClient.requireLogin() {
            throw BaseError.runtimeError("UstcBlackboard Not logined")
        }

        let events = try await USTCBlackboardService().fetchCalendarEvents()

        // remove all old homework entries
        try! SwiftDataStack.modelContext.delete(model: Homework.self)

        for event in events {
            guard let dueDate = USTCBlackboardService.parseDate(event.endDate) else {
                continue
            }

            let title = event.title
            let courseName = event.courseName

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

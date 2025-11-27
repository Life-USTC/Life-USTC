//
//  Semester.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Semester {
    @Attribute(.unique) var id: String
    var courses: [Course]
    var name: String
    var startDate: Date
    var endDate: Date
    @Relationship var curriculum: Curriculum?

    var isCurrent: Bool {
        let today = Date().stripTime()
        return (startDate ... endDate).contains(today)
    }

    init(id: String, courses: [Course], name: String, startDate: Date, endDate: Date) {
        self.id = id
        self.courses = courses
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}

extension Semester {
    var coursesQuery: [Course] {
        let context = SwiftDataStack.context
        let myID = self.persistentModelID
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.semester?.persistentModelID == myID })
        return (try? context.fetch(descriptor)) ?? []
    }
    static let example = Semester(
        id: "2025-Fall",
        courses: [],
        name: "Example Semester",
        startDate: Date().addingTimeInterval(-7 * 24 * 3600),
        endDate: Date().addingTimeInterval(7 * 24 * 3600)
    )
}

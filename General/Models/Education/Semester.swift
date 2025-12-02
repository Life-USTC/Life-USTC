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
    var curriculum: Curriculum?
    @Relationship(deleteRule: .cascade, inverse: \Course.semester) var courses: [Course]?

    @Attribute(.unique) var jw_id: String
    var name: String
    var startDate: Date
    var endDate: Date

    var isCurrent: Bool {
        startDate ... endDate ~= Date().stripTime()
    }

    init(
        jw_id: String,
        name: String,
        startDate: Date,
        endDate: Date
    ) {
        self.jw_id = jw_id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}

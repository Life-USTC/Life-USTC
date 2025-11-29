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

    @Attribute(.unique) var id: String
    var name: String
    var startDate: Date
    var endDate: Date

    var isCurrent: Bool {
        startDate ... endDate ~= Date().stripTime()
    }

    init(
        curriculum: Curriculum?,
        id: String,
        name: String,
        startDate: Date,
        endDate: Date
    ) {
        self.curriculum = curriculum
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}

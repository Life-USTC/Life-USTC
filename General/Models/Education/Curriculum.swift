//
//  Curriculum.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation
import SwiftData

@Model
final class Curriculum {
    @Attribute(.unique) var uniqueID = 0
    @Relationship(deleteRule: .cascade, inverse: \Semester.curriculum) var semesters: [Semester] = []

    init() {}
}

extension Curriculum {
    static func update() async throws {
        try await SchoolSystem.current.updateCurriculum()
    }
}

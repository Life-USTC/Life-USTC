//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftData
import SwiftUI

@Model
final class Exam {
    var lessonCode: String
    var courseName: String

    var typeName: String
    var startDate: Date
    var endDate: Date
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var detailText: String

    init(
        lessonCode: String,
        courseName: String,
        typeName: String,
        startDate: Date,
        endDate: Date,
        classRoomName: String,
        classRoomBuildingName: String,
        classRoomDistrict: String,
        description: String
    ) {
        self.lessonCode = lessonCode
        self.courseName = courseName
        self.typeName = typeName
        self.startDate = startDate
        self.endDate = endDate
        self.classRoomName = classRoomName
        self.classRoomBuildingName = classRoomBuildingName
        self.classRoomDistrict = classRoomDistrict
        self.detailText = description
    }
}

// extension Exam {
//     static let example = Exam(
//         lessonCode: "EX-101",
//         courseName: "Example Course",
//         typeName: "Final",
//         startDate: Date(),
//         endDate: Date().addingTimeInterval(7200),
//         classRoomName: "101",
//         classRoomBuildingName: "Main Building",
//         classRoomDistrict: "East",
//         description: "Seat 12"
//     )
// }

// extension Array where Element == Exam {
//     static let example: [Exam] = [Exam.example]
// }

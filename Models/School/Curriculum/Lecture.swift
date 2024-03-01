//
//  Lecture.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import EventKit
import SwiftUI

/// Represent one lecture
struct Lecture: Codable, Identifiable, Equatable {
    var id: UUID {
        UUID()
    }

    var startDate: Date
    var endDate: Date
    var name: String
    var location: String = ""
    var teacherName: String = ""
    var periods: Double = 0
    var additionalInfo: [String: String] = [:]
    var startIndex: Int?
    var endIndex: Int?

    static let example = Lecture(
        startDate: Date().stripTime() + DateComponents(hour: 7, minute: 50),
        endDate: Date().stripTime() + DateComponents(hour: 12, minute: 10),
        name: "数学分析B1",
        location: "5104",
        startIndex: 1,
        endIndex: 5
    )
}

extension EKEvent {
    convenience init(
        _ lecture: Lecture,
        in store: EKEventStore = EKEventStore()
    ) {
        self.init(eventStore: store)
        title = lecture.name
        startDate = lecture.startDate
        endDate = lecture.endDate
        location = lecture.location
    }
}

extension [Lecture] {
    func sort() -> [Lecture] {
        sorted { $0.startDate < $1.startDate }
    }

    func union() -> [Lecture] {
        var unionedLectures: [Lecture] = []
        for lecture in self {
            if let lastLecture = unionedLectures.last {
                if lecture.startDate == lastLecture.startDate,
                    lecture.endDate == lastLecture.endDate,
                    lecture.name == lastLecture.name,
                    lecture.location == lastLecture.location,
                    lecture.periods == lastLecture.periods,
                    lecture.additionalInfo == lastLecture.additionalInfo
                {
                    unionedLectures[unionedLectures.count - 1].teacherName += ("、" + lecture.teacherName)
                } else {
                    unionedLectures.append(lecture)
                }
            } else {
                unionedLectures.append(lecture)
            }
        }
        return unionedLectures
    }
}

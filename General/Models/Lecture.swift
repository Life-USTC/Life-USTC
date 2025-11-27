//
//  Lecture.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import EventKit
import SwiftData
import SwiftUI

@Model
final class Lecture {
    var startDate: Date
    var endDate: Date
    var name: String
    var location: String = ""
    var teacherName: String = ""
    var periods: Double = 0
    var additionalInfo: [String: String] = [:]
    var startIndex: Int?
    var endIndex: Int?
    @Relationship var course: Course?

    init(
        startDate: Date,
        endDate: Date,
        name: String,
        location: String = "",
        teacherName: String = "",
        periods: Double = 0,
        additionalInfo: [String: String] = [:],
        startIndex: Int? = nil,
        endIndex: Int? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.name = name
        self.location = location
        self.teacherName = teacherName
        self.periods = periods
        self.additionalInfo = additionalInfo
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

extension EKEvent {
    convenience init(
        _ lecture: Lecture,
        in store: EKEventStore = EKEventStore()
    ) {
        self.init(eventStore: store)

        self.title = lecture.name
        self.startDate = lecture.startDate
        self.endDate = lecture.endDate
        self.location = lecture.location
    }
}

extension Lecture: Comparable {
    static func < (lhs: Lecture, rhs: Lecture) -> Bool {
        lhs.startDate < rhs.startDate
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

    func clean() -> [Lecture] {
        let lectures = self.union()
        return
            (lectures.filter { $0.startDate > Date() }
            + lectures.filter { $0.startDate <= Date() })
    }
}

extension Lecture {
    static let example = Lecture(
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        name: "Example Lecture",
        location: "Example Building",
        teacherName: "Example Teacher",
        periods: 1
    )
}

extension Lecture {
    var color: Color { course?.color ?? .accentColor }
}

//

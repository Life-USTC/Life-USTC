//
//  Lecture.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import EventKit
import SwiftUI

/// Represent one lecture
class Lecture: Codable, Identifiable, Equatable {
    var startDate: Date
    var endDate: Date
    var name: String
    var location: String = ""
    var teacherName: String = ""
    var periods: Double = 0
    var additionalInfo: [String: String] = [:]
    var startIndex: Int?
    var endIndex: Int?

    var course: Course?

    enum CodingKeys: String, CodingKey {
        case startDate
        case endDate
        case name
        case location
        case teacherName
        case periods
        case additionalInfo
        case startIndex
        case endIndex
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(String.self, forKey: .location)
        teacherName = try container.decode(String.self, forKey: .teacherName)
        periods = try container.decode(Double.self, forKey: .periods)
        additionalInfo = try container.decode([String: String].self, forKey: .additionalInfo)
        startIndex = try container.decodeIfPresent(Int.self, forKey: .startIndex)
        endIndex = try container.decodeIfPresent(Int.self, forKey: .endIndex)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(name, forKey: .name)
        try container.encode(location, forKey: .location)
        try container.encode(teacherName, forKey: .teacherName)
        try container.encode(periods, forKey: .periods)
        try container.encode(additionalInfo, forKey: .additionalInfo)
        try container.encodeIfPresent(startIndex, forKey: .startIndex)
        try container.encodeIfPresent(endIndex, forKey: .endIndex)
    }

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

    static let example = Lecture(
        startDate: Date().stripTime() + DateComponents(hour: 7, minute: 50),
        endDate: Date().stripTime() + DateComponents(hour: 12, minute: 10),
        name: "数学分析B1",
        location: "5104",
        teacherName: "EXAMPLE",
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

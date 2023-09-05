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
    var id: UUID = .init()
    var startDate: Date
    var endDate: Date
    var name: String
    var location: String = ""
    var teacher: String = ""
    var periods: Double = 0
    var additionalInfo: [String: String] = [:]

    static let example = Lecture(
        startDate: Date(),
        endDate: Date() + DateComponents(hour: 3),
        name: "数学分析B1",
        location: "5104"
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
}

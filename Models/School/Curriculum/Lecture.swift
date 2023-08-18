//
//  Lecture.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import EventKit
import SwiftUI

/// Represent one lecture
struct Lecture: Codable {
    var startDate: Date
    var endDate: Date
    var name: String
    var location: String

    static var example = Self(startDate: Date(),
                              endDate: Date() + DateComponents(hour: 1),
                              name: "Example Lecture",
                              location: "Example Location")
}

extension Lecture {
    /// Convert to EKEvent
    func event(in store: EKEventStore = EKEventStore()) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = name
        event.startDate = startDate
        event.endDate = endDate
        event.location = String(location)
        return event
    }
}

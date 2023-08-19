//
//  Course.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import Foundation

struct Course: Codable {
    var name: String
    var code: String
    var teacherName: String
    var lectures: [Lecture]
    var description: String = ""
    var credit: Double = 0
    var additionalInfo: [String: String] = [:]

    static var example = Self(name: "Example Course",
                              code: "Example Code",
                              teacherName: "Example Teacher",
                              lectures: [.example])
}

extension Course {
    /// Convert to EKEvent
    func events(in store: EKEventStore = EKEventStore()) -> [EKEvent] {
        lectures.map { $0.event(in: store) }
    }
}

extension Course: Identifiable {
    var id: UUID {
        UUID()
    }
}

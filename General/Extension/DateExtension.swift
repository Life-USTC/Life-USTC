//
//  DateExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/18.
//

import SwiftUI

func + (lhs: Date, rhs: DateComponents) -> Date {
    Calendar.current.date(byAdding: rhs, to: lhs)!
}

extension Date {
    /// Base time at 1970
    static var zero: Date {
        Date(timeIntervalSince1970: 0)
    }

    /// Keep hour and minute only
    func stripHMwithTimezone() -> String {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: self
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let formattedDate = dateFormatter.string(from: Calendar.current.date(from: components)!)

        return formattedDate
    }

    /// Keep year month and day components only
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: self
        )
        return Calendar.current.date(from: components)!
    }

    /// Keep hour minute second. nanosecond components only
    func stripDate() -> Date {
        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second, .nanosecond],
            from: self
        )
        return Calendar.current.date(from: components)!
    }

    /// hour * 60 + minute
    var minutesSinceMidnight: Int {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: self
        )
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Shorthand for adding DateComponents
    func add(year: Int = 0, month: Int = 0, day: Int = 0) -> Date {
        self + DateComponents(year: year, month: month, day: day)
    }

    /// Start of this week
    func startOfWeek() -> Date {
        Calendar(identifier: .gregorian)
            .dateComponents(
                [.calendar, .yearForWeekOfYear, .weekOfYear],
                from: self
            )
            .date!
    }
}

extension DateComponents {
    @available(*, deprecated, message: "Use String/Text to format instead")
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: .zero + self)
    }
}

// Enable @AppStorage ... Date
extension Date: @retroactive RawRepresentable {
    public var rawValue: String { timeIntervalSinceReferenceDate.description }

    public init?(rawValue: String) {
        self = Date(timeIntervalSinceReferenceDate: Double(rawValue) ?? 0.0)
    }

    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: self)
    }
}

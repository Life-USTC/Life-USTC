//
//  DateExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/18.
//

import SwiftUI

/// Operator overload to add DateComponents to a Date
/// - Parameters:
///   - lhs: The base Date
///   - rhs: DateComponents to add
/// - Returns: New Date with components added
func + (lhs: Date, rhs: DateComponents) -> Date {
    Calendar.current.date(byAdding: rhs, to: lhs)!
}

extension Date {
    /// Base time at Unix epoch (1970-01-01 00:00:00 UTC)
    static var zero: Date {
        Date(timeIntervalSince1970: 0)
    }

    /// Returns time string in HH:mm format (24-hour)
    /// - Returns: Formatted time string like "14:30"
    func stripHMwithTimezone() -> String {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: self
        )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.locale = Locale(identifier: "en_GB")
        let formattedDate = dateFormatter.string(from: Calendar.current.date(from: components)!)

        return formattedDate
    }

    /// Removes time components, keeping only year, month, and day
    /// Useful for date-only comparisons
    /// - Returns: Date with time set to 00:00:00
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: self
        )
        return Calendar.current.date(from: components)!
    }

    /// Removes date components, keeping only time (hour, minute, second, nanosecond)
    /// - Returns: Time portion of the date from midnight
    func stripDate() -> Date {
        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second, .nanosecond],
            from: self
        )
        return Calendar.current.date(from: components)!
    }

    /// Calculate total minutes since midnight
    /// - Returns: Number of minutes (hour * 60 + minute)
    var minutesSinceMidnight: Int {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: self
        )
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Convenience method to add date components
    /// - Parameters:
    ///   - year: Years to add (default 0)
    ///   - month: Months to add (default 0)
    ///   - day: Days to add (default 0)
    /// - Returns: New Date with components added
    func add(year: Int = 0, month: Int = 0, day: Int = 0) -> Date {
        self + DateComponents(year: year, month: month, day: day)
    }

    /// Returns the start of the week (Monday) for this date
    /// - Returns: Date representing the beginning of the week
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

/// Enable @AppStorage to store Date values
/// Stores dates as time intervals since reference date
extension Date: @retroactive RawRepresentable {
    public var rawValue: String { timeIntervalSinceReferenceDate.description }

    public init?(rawValue: String) {
        self = Date(timeIntervalSinceReferenceDate: Double(rawValue) ?? 0.0)
    }

    /// Returns formatted time string (short style)
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: self)
    }
}

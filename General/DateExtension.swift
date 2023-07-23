//
//  DateExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/18.
//

import SwiftUI

let daysOfWeek: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

func weekday(for date: Date = Date()) -> Int {
    mod(Calendar(identifier: .gregorian).component(.weekday, from: date) - 2, 7) + 1
}

var defaultDateFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    return dateFormatter
}

var longDateFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter
}

/// Represent a certain peroid of time
///
/// The concept is generally related to today, say 2000/10/1 for example,
/// When shown to user, we usually take these five segments: (both sides included)
/// Today: 2000/9/30 - 2000/10/1
/// This week: 2000/9/XX - 2020/9/19
/// ...
enum TimePeroid: Int, CaseIterable {
    case day = 1
    case week = 7
    case month = 30
    case year = 365
    case longerThanAYear = 400

    var caption: String {
        switch self {
        case .day:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .year:
            return "This Year"
        case .longerThanAYear:
            return "Longer than a year"
        }
    }

    var dateRange: any RangeExpression<Date> {
        let base = Date().stripTime()
        switch self {
        case .day:
            return base.add(day: -1) ... base.add(day: 1)
        case .week:
            return base.add(day: -7) ..< base.add(day: -1)
        case .month:
            return base.add(month: -1) ..< base.add(day: -7)
        case .year:
            return base.add(year: -1) ..< base.add(month: -1)
        case .longerThanAYear:
            return Date.zero ..< base.add(year: -1)
        }
    }

    var dateRangeCaption: String {
        let base = Date().stripTime()
        var from, to: Date

        switch self {
        case .day:
            (from, to) = (base.add(day: -1), base)
        case .week:
            (from, to) = (base.add(day: -7), base.add(day: -2))
        case .month:
            (from, to) = (base.add(month: -1), base.add(day: -8))
        case .year:
            (from, to) = (base.add(year: -1), base.add(month: -1, day: -1))
        case .longerThanAYear:
            return "Before " + String(base.add(year: -1, day: -1))
        }
        return String(from) + " - " + String(to)
    }
}

func + (lhs: Date, rhs: DateComponents) -> Date {
    Calendar.current.date(byAdding: rhs, to: lhs)!
}

extension Date {
    /// Base time at 1970
    static var zero: Date {
        Date(timeIntervalSince1970: 0)
    }

    /// Keep year month and day components only
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return Calendar.current.date(from: components)!
    }

    /// Shorthand for adding DateComponents
    func add(year: Int = 0, month: Int = 0, day: Int = 0) -> Date {
        self + DateComponents(year: year, month: month, day: day)
    }
}

extension String {
    /// Format date with default formatter
    init(_ date: Date, long: Bool = false) {
        self = defaultDateFormatter.string(from: date)
        if long {
            self = longDateFormatter.string(from: date)
        }
    }
}

extension DateComponents {
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: Date().stripTime() + self)
    }
}

//
//  DateExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/18.
//

import SwiftUI

let daysOfWeek: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

func weekday(for date: Date = Date()) -> Int {
    ((Calendar(identifier: .gregorian).component(.weekday, from: date) - 2) %% 7) + 1
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

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

    /// Keep year month and day components only
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return Calendar.current.date(from: components)!
    }

    func stripDate() -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: self)
        return Calendar.current.date(from: components)!
    }

    var HHMM: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Shorthand for adding DateComponents
    func add(year: Int = 0, month: Int = 0, day: Int = 0) -> Date {
        self + DateComponents(year: year, month: month, day: day)
    }

    func startOfWeek() -> Date {
        Calendar.current.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
    }
}

extension DateComponents {
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: .zero + self)
    }
}

//
//  PostModel.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/18.
//

import SwiftUI

enum TimeIntervalEnum: Int, CaseIterable {
    case day = 1
    case week = 7
    case month = 30
    case year = 365
    case longerThanAYear = 400
    
    var descriptionString: LocalizedStringKey {
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
    
    var rangeToContain: any RangeExpression<Date> {
        let currentDate = Date().stripTime()
        switch self {
        case .day:
            return currentDate + DateComponents(day: -1) ... currentDate
        case .week:
            return currentDate + DateComponents(day: -7) ..< currentDate + DateComponents(day: -1)
        case .month:
            return currentDate + DateComponents(month: -1) ..< currentDate + DateComponents(day: -7)
        case .year:
            return currentDate + DateComponents(year: -1) ..< currentDate + DateComponents(month: -1)
        case .longerThanAYear:
            return Date(timeIntervalSince1970: 0) ..< currentDate + DateComponents(year: -1)
        }
    }
    
    var showDate: LocalizedStringKey {
        let currentDate = Date().stripTime()
        var startDate: Date?
        var endDate: Date
        switch self {
        case .day:
            startDate = currentDate + DateComponents(day: -1)
            endDate = currentDate + DateComponents(day: 0)
        case .week:
            startDate = currentDate + DateComponents(day: -7)
            endDate = currentDate + DateComponents(day: -2)
        case .month:
            startDate = currentDate + DateComponents(month: -1)
            endDate = currentDate + DateComponents(day: -8)
        case .year:
            startDate = currentDate + DateComponents(year: -1)
            endDate = currentDate + DateComponents(month: -1, day: -1)
        case .longerThanAYear:
            endDate = currentDate + DateComponents(year: -1, day: -1)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        if let startDate {
            return LocalizedStringKey(dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate))
        } else {
            return LocalizedStringKey("Before \(dateFormatter.string(from: endDate))")
        }
    }
}

func + (lhs: Date, rhs: DateComponents) -> Date {
    return Calendar.current.date(byAdding: rhs, to: lhs)!
}

extension Date {
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents([.year,.month,.day], from: self)
        return Calendar.current.date(from: components)!
    }
}

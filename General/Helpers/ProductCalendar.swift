import Foundation

/// Gregorian/Shanghai civil-date boundaries shared by the app and Widget.
/// Every product week starts Sunday; persisted event timestamps stay unchanged.
enum ProductCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        value.firstWeekday = 1
        value.minimumDaysInFirstWeek = 1
        return value
    }

    static func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    static func dayRange(containing date: Date) -> Range<Date> {
        let start = dayStart(date)
        return start ..< addingDays(1, to: start)
    }

    static func weekRange(containing date: Date) -> Range<Date> {
        let day = dayStart(date)
        let start = addingDays(1 - calendar.component(.weekday, from: day), to: day)
        return start ..< addingDays(7, to: start)
    }

    /// Labels the selected calendar week, not a meeting's stored teaching week.
    /// A display row can extend outside the term; it never creates meetings.
    static func teachingWeekNumber(
        containing date: Date, semesterStart: Date, semesterEnd: Date
    ) -> Int? {
        guard semesterStart > .distantPast, semesterEnd < .distantFuture,
              semesterStart <= semesterEnd else { return nil }
        let week = weekRange(containing: date)
        guard week.upperBound > dayStart(semesterStart),
              week.lowerBound <= dayStart(semesterEnd) else { return nil }
        let first = weekRange(containing: semesterStart).lowerBound
        let days = calendar.dateComponents([.day], from: first, to: week.lowerBound).day!
        return days / 7 + 1
    }
}

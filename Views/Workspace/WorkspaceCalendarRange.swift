import Foundation

enum WorkspaceCalendarMode: String, CaseIterable, Identifiable {
    case day, week, month, semester
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct WorkspaceCalendarDay: Identifiable {
    let date: Date
    let events: [ServerPersonalCalendarEvent]
    var id: String { YoungCalendarDate.dateString(date) }
}

struct ServerCalendarRange {
    let start: Date
    let end: Date

    init(start: Date, end: Date) {
        self.start = YoungCalendarDate.dayStart(start)
        self.end = YoungCalendarDate.dayStart(end)
    }

    var days: [Date] {
        var dates: [Date] = []
        var day = start
        while day <= end {
            dates.append(day)
            day = YoungCalendarDate.calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return dates
    }

    var requestWindows: [(from: String, to: String)] {
        var windows: [(String, String)] = []
        var day = start
        while day <= end {
            let last = min(YoungCalendarDate.calendar.date(byAdding: .day, value: 365, to: day)!, end)
            windows.append((YoungCalendarDate.dateString(day), YoungCalendarDate.dateString(last)))
            day = YoungCalendarDate.calendar.date(byAdding: .day, value: 1, to: last)!
        }
        return windows
    }
}

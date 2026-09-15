//
//  ServerYoungModels.swift
//  Life@USTC
//
//  Models for Second Classroom catalog and workspace APIs.
//

import Foundation

enum YoungEventTimeBasis: String, CaseIterable, Identifiable, Codable {
    case activity
    case registration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: "Activity time"
        case .registration: "Registration window"
        }
    }
}

enum YoungCalendarDisplayMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

/// Calendar calculations for the product contract: Asia/Shanghai and Monday weeks.
enum YoungCalendarDate {
    static let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = shanghai
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func weekStart(_ date: Date) -> Date {
        let day = dayStart(date)
        let weekday = calendar.component(.weekday, from: day)
        let mondayOffset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -mondayOffset, to: day) ?? day
    }

    static func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? dayStart(date)
    }

    static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func range(for mode: YoungCalendarDisplayMode, date: Date) -> (from: String, to: String) {
        let start: Date
        let end: Date
        switch mode {
        case .day:
            start = dayStart(date)
            end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
        case .week:
            start = weekStart(date)
            end = calendar.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
        case .month:
            start = monthStart(date)
            end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
        }
        return (dateString(start), dateString(end))
    }

    static func advance(_ date: Date, mode: YoungCalendarDisplayMode, amount: Int = 1) -> Date {
        switch mode {
        case .day: calendar.date(byAdding: .day, value: amount, to: date) ?? date
        case .week: calendar.date(byAdding: .day, value: amount * 7, to: date) ?? date
        case .month: calendar.date(byAdding: .month, value: amount, to: date) ?? date
        }
    }
}

struct ServerYoungEvent: Codable, Identifiable, Hashable {
    let youngId: String
    let name: String
    let category: String?
    let department: String?
    let organizer: String?
    let organizerId: String?
    let status: String?
    let registrationStatus: String?
    let location: String?
    let imageUrl: String?
    let hours: Double?
    let capacity: Int?
    let appliedCount: Int?
    let startAt: Date?
    let endAt: Date?
    let applyStartAt: Date?
    let applyEndAt: Date?
    let isActive: Bool
    let sourceMissing: Bool?
    let dateUnknown: Bool?
    let lastSeenAt: Date?
    let createdAt: Date?

    var id: String { youngId }

    var officialSignupURL: URL? {
        URL(string: "https://young.ustc.edu.cn")
    }

    func dateRange(for basis: YoungEventTimeBasis) -> (Date?, Date?) {
        switch basis {
        case .activity: (startAt, endAt)
        case .registration: (applyStartAt, applyEndAt)
        }
    }
}

struct ServerYoungCatalogSource: Codable, Hashable {
    let status: String
    let lastSyncedAt: Date?
}

struct ServerYoungEventsPage: Codable {
    let data: [ServerYoungEvent]
    let pagination: PaginationInfo
    let unknownDateCount: Int
    let source: ServerYoungCatalogSource

    init(
        data: [ServerYoungEvent],
        pagination: PaginationInfo,
        unknownDateCount: Int,
        source: ServerYoungCatalogSource
    ) {
        self.data = data
        self.pagination = pagination
        self.unknownDateCount = unknownDateCount
        self.source = source
    }
}

struct ServerYoungOrganizer: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let normalizedName: String
    let totalCount: Int?
    let activeCount: Int?
    let upcomingCount: Int?
    let historyCount: Int?
}

struct ServerPersonalCalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let at: Date?
    let endsAt: Date?
    let title: String
    let location: String?
    let url: String
    let youngId: String?
}

struct ServerYoungEventSubscription: Codable, Identifiable {
    let youngId: String
    let createdAt: Date
    let remindSignup: Bool
    let remindDeadline: Bool
    let remindStart: Bool
    let event: ServerYoungEvent

    var id: String { youngId }
}

struct ServerYoungEventSubscriptionState: Codable {
    let youngId: String
    let subscribed: Bool
    let remindSignup: Bool
    let remindDeadline: Bool
    let remindStart: Bool
}

struct YoungEventSubscriptionRequest: Encodable {
    let subscribed: Bool
    let remindSignup: Bool?
    let remindDeadline: Bool?
    let remindStart: Bool?

    init(
        subscribed: Bool,
        remindSignup: Bool? = nil,
        remindDeadline: Bool? = nil,
        remindStart: Bool? = nil
    ) {
        self.subscribed = subscribed
        self.remindSignup = remindSignup
        self.remindDeadline = remindDeadline
        self.remindStart = remindStart
    }
}

struct ServerYoungOrganizerReference: Codable, Hashable {
    let id: String
    let name: String
}

struct ServerYoungOrganizerSubscription: Codable, Identifiable {
    let organizerId: String
    let createdAt: Date
    let organizer: ServerYoungOrganizerReference

    var id: String { organizerId }
}

struct ServerYoungOrganizerSubscriptionState: Codable {
    let organizerId: String
    let subscribed: Bool
}

struct YoungOrganizerSubscriptionRequest: Encodable {
    let subscribed: Bool
}

struct ServerYoungNotification: Codable, Identifiable {
    let id: String
    let youngId: String?
    let organizerId: String?
    let kind: String
    let title: String
    let body: String
    let createdAt: Date
    let readAt: Date?
    let expiresAt: Date?

    var isRead: Bool { readAt != nil }
}

struct ServerYoungNotificationRead: Codable {
    let id: String
    let success: Bool
}

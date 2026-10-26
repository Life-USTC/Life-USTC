//
//  ServerYoungModels.swift
//  Life@USTC
//
//  Models for Second Classroom catalog and workspace APIs.
//

import Foundation
import LifeClientCore

enum YoungEventTimeBasis: String, CaseIterable, Identifiable, Codable {
    case activity
    case registration

    var id: String { rawValue }

    var queryValue: YoungTimeBasis {
        switch self {
        case .activity: .activity
        case .registration: .registration
        }
    }

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
        dateFormatter.date(from: range(for: .week, date: date).from)!
    }

    static func monthStart(_ date: Date) -> Date {
        dateFormatter.date(from: range(for: .month, date: date).from)!
    }

    static func dateString(_ date: Date) -> String {
        ClientCalendar.shanghaiDate(at: date)
    }

    static func range(
        for mode: YoungCalendarDisplayMode, date: Date,
        firstWeekday: CalendarWeekday = .monday
    ) -> (from: String, to: String) {
        let period: CalendarPeriod = switch mode {
        case .day: .day
        case .week: .week
        case .month: .month
        }
        let value = try! ClientCalendar.bounds(period: period, at: date, firstWeekday: firstWeekday)
        return (value.from, value.to)
    }

    static func advance(_ date: Date, mode: YoungCalendarDisplayMode, amount: Int = 1) -> Date {
        switch mode {
        case .day: calendar.date(byAdding: .day, value: amount, to: date) ?? date
        case .week: calendar.date(byAdding: .day, value: amount * 7, to: date) ?? date
        case .month: calendar.date(byAdding: .month, value: amount, to: date) ?? date
        }
    }
}

struct ServerYoungEventPlace: Codable, Hashable {
    let placeInfo: String?
    let placeSt: String?
    let placeEt: String?
}

struct ServerCalendarConflictInterval: Codable, Hashable {
    let startAt: Date
    let endAt: Date
}

struct ServerYoungEvent: Codable, Identifiable, Hashable {
    let youngId: String
    let name: String
    let category: String?
    let department: String?
    let organizer: String?
    let organizerId: String?
    let status: String?
    let activityStatusCode: String?
    let signupStatusCode: String?
    let requiresSignup: Bool?
    let categoryCode: String?
    let moduleCode: String?
    let formCode: String?
    let activityLevelCode: String?
    let departmentId: String?
    let upstreamOrganizerIds: [String]
    let upstreamSponsorIds: [String]
    let tagIds: [String]
    let signupScopeCode: String?
    let signupDepartmentIds: [String]
    let requiresSignupInfo: Bool?
    let allowedAttachmentTypes: [String]
    let isOnline: Bool?
    let onlineMeetingInfo: String?
    let externalSponsor: String?
    let description: String?
    let participationNotes: String?
    let activityLevel: String?
    let module: String?
    let form: String?
    let grades: String?
    let sponsor: String?
    let contactName: String?
    let contactTel: String?
    let duration: Double?
    let serviceHour: Double?
    let sumHours: Double?
    let sumPersons: Int?
    let partakeNum: Int?
    let favCount: Int?
    let limitNum: Int?
    let createdAtUpstream: Date?
    let auditedAt: Date?
    let updatedAtUpstream: Date?
    let places: [ServerYoungEventPlace]?
    let location: String?
    let imageUrl: String?
    let hours: Double?
    let capacity: Int?
    let appliedCount: Int?
    let startAt: Date?
    let endAt: Date?
    let conflictIntervals: [ServerCalendarConflictInterval]?
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
    struct Metadata: Codable {
        let unknownDateCount: Int
        let source: ServerYoungCatalogSource
    }

    let data: [ServerYoungEvent]
    let pagination: PaginationInfo
    let meta: Metadata

    var unknownDateCount: Int { meta.unknownDateCount }
    var source: ServerYoungCatalogSource { meta.source }
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

enum ServerCalendarTargetKind: String, Codable, Hashable {
    case section, exam, homework, todo
    case youngEvent = "young_event"
}

struct ServerCalendarTarget: Codable, Hashable {
    let kind: ServerCalendarTargetKind
    let id: String
}

struct ServerPersonalCalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let at: Date?
    let endsAt: Date?
    let conflictIntervals: [ServerCalendarConflictInterval]?
    let title: String
    let location: String?
    let url: String
    let youngId: String?
    let target: ServerCalendarTarget?
    let sectionJwId: Int?
    let sectionCode: String?
    let teachers: [String]?
    let subscriptionKind: ServerSubscriptionKind?
    let priority: TodoPriority?
    let content: String?
    let examMode: String?
    let hasTime: Bool?
    let completionRequired: Bool?
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

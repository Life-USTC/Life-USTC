import Foundation

struct ServerTodoFilters: Equatable {
    var completed: Bool? = nil
    var priority: TodoPriority? = nil
    var dueBefore: Date? = nil
    var dueAfter: Date? = nil
}

struct ServerTodoCounts: Codable, Equatable {
    let completed: Int
    let incomplete: Int
    let overdue: Int
}

struct ServerTodoPageResponse: Codable {
    struct Metadata: Codable { let counts: ServerTodoCounts }
    let data: [ServerTodo]
    let pagination: PaginationInfo
    let meta: Metadata
}

struct ServerTodoCollection {
    let counts: ServerTodoCounts
    let todos: [ServerTodo]
}

struct ServerTodoUpdateResponse: Codable {
    let success: Bool
    let todo: ServerTodo
}

struct ServerWorkspaceSection: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let courseId: Int
    let semesterId: Int?
    let course: ServerCourseSummary
    let semester: ServerSemester?
}

struct ServerExamFilters: Equatable {
    var semesterID: Int? = nil
    var dateFrom: String? = nil
    var dateTo: String? = nil
    var includeDateUnknown = true
    var locale: String? = nil
}

struct ServerWorkspaceExam: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let sectionId: Int
    let examDate: Date?
    let startTime: Int?
    let endTime: Int?
    let examType: Int?
    let examMode: String?
    let examTakeCount: Int?
    let examBatch: NamedEntity?
    let examRooms: [ServerExamRoom]
    let section: ServerWorkspaceSection
}

enum ServerOverviewFocusStatus: String, Codable {
    case now, urgent, next
}

struct ServerOverviewFocus: Decodable {
    let event: ServerPersonalCalendarEvent
    let status: ServerOverviewFocusStatus

    private enum CodingKeys: String, CodingKey { case status }

    init(from decoder: Decoder) throws {
        event = try ServerPersonalCalendarEvent(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(ServerOverviewFocusStatus.self, forKey: .status)
    }
}

struct ServerActionableOverview: Decodable {
    struct Anchor: Decodable {
        let atTime: Date
        let dateFrom: Date
        let dateTo: Date
    }

    struct Deadlines: Decodable {
        let today: [ServerPersonalCalendarEvent]
        let nextThreeDays: [ServerPersonalCalendarEvent]
        let allPending: [ServerPersonalCalendarEvent]
    }

    struct Subscriptions: Decodable {
        struct Semester: Decodable, Identifiable {
            let id: Int
            let nameCn: String
            let startDate: Date
            let endDate: Date
        }
        let totalCount: Int
        let currentSemesterCount: Int
        let currentSemester: Semester?
    }

    let anchor: Anchor
    let focus: ServerOverviewFocus?
    let urgency: [ServerPersonalCalendarEvent]
    let upcoming: [ServerPersonalCalendarEvent]
    let deadlines: Deadlines
    let subscriptions: Subscriptions
}

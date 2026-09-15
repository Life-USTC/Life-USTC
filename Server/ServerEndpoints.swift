//
//  ServerEndpoints.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation

// MARK: - Endpoint Definition

enum ServerEndpoint {
    // User
    case me

    // Semesters
    case listSemesters(page: Int?, pageSize: Int?)
    case currentSemester

    // Courses
    case listCourses(query: String?, page: Int?, pageSize: Int?)
    case getCourse(jwId: String)

    // Sections
    case listSections(query: String?, semesterId: Int?, courseId: Int?, page: Int?, pageSize: Int?)
    case getSection(jwId: String)
    case getSectionSchedules(jwId: String)
    case matchCodes(MatchCodesRequest)

    // Teachers
    case listTeachers(query: String?, page: Int?, pageSize: Int?)
    case getTeacher(id: Int)

    // Schedules
    case querySchedules(sectionId: Int?, teacherId: Int?, room: String?, date: String?, weekday: Int?)

    // Calendar Subscriptions
    case getSubscriptions
    case updateSubscriptions(UpdateSubscriptionRequest)

    // Calendar Events
    case listCalendarEvents(dateFrom: String, dateTo: String, page: Int, pageSize: Int)

    // Second Classroom (public catalog)
    case listYoungEvents(
        dateUnknown: Bool?, active: Bool?, category: String?, search: String?, organizerId: String?,
        dateFrom: String?, dateTo: String?, timeBasis: YoungEventTimeBasis?,
        page: Int?, pageSize: Int?
    )
    case getYoungEvent(youngId: String)
    case listYoungOrganizers(search: String?, page: Int?, pageSize: Int?)
    case getYoungOrganizer(organizerId: String)

    // Second Classroom (authenticated workspace)
    case listYoungEventSubscriptions(page: Int, pageSize: Int, unread: Bool?)
    case getYoungEventSubscription(youngId: String)
    case updateYoungEventSubscription(youngId: String, YoungEventSubscriptionRequest)
    case listYoungOrganizerSubscriptions(page: Int, pageSize: Int, unread: Bool?)
    case getYoungOrganizerSubscription(organizerId: String)
    case updateYoungOrganizerSubscription(organizerId: String, YoungOrganizerSubscriptionRequest)
    case listYoungNotifications(page: Int, pageSize: Int, unread: Bool?)
    case markYoungNotificationRead(id: String)

    // Overview
    case overview

    // Homeworks
    case listHomeworks(sectionId: Int?, subscribedOnly: Bool?)
    case getHomework(id: String)
    case createHomework(CreateHomeworkRequest)
    case updateHomework(id: String, UpdateHomeworkRequest)
    case deleteHomework(id: String)
    case setHomeworkCompletion(id: String, HomeworkCompletionRequest)

    // Todos
    case listTodos
    case createTodo(CreateTodoRequest)
    case updateTodo(id: String, UpdateTodoRequest)
    case deleteTodo(id: String)

    // Comments
    case listComments(
        targetType: String, targetId: String?,
        youngId: String?, sectionId: Int?, teacherId: Int?,
        page: Int?, pageSize: Int?
    )
    case createComment(CreateCommentRequest)
    case listCommentReplies(id: String, cursor: String?, pageSize: Int?)
    case addCommentReaction(id: String, CommentReactionRequest)
    case removeCommentReaction(id: String, type: String)

    // Bus
    case busSchedule(
        originCampusId: Int?, destinationCampusId: Int?,
        dayType: String?, limit: Int?
    )

    // Metadata
    case metadata

    // Uploads
    case listUploads
    case createUpload(CreateUploadRequest)

    // MARK: - Properties

    var method: String {
        switch self {
        case .me, .currentSemester, .listSemesters,
            .listCourses, .getCourse,
            .listSections, .getSection, .getSectionSchedules,
            .listTeachers, .getTeacher,
            .querySchedules,
            .getSubscriptions, .listCalendarEvents,
            .listYoungEvents, .getYoungEvent, .listYoungOrganizers,
            .getYoungOrganizer, .listYoungEventSubscriptions,
            .getYoungEventSubscription, .listYoungOrganizerSubscriptions,
            .getYoungOrganizerSubscription, .listYoungNotifications,
            .overview,
            .listHomeworks, .getHomework, .listTodos,
            .listComments, .listCommentReplies,
            .busSchedule, .metadata, .listUploads:
            return "GET"
        case .matchCodes, .updateSubscriptions, .createHomework,
            .createTodo, .createComment, .addCommentReaction,
            .markYoungNotificationRead, .createUpload:
            return "POST"
        case .updateYoungEventSubscription, .updateYoungOrganizerSubscription:
            return "PUT"
        case .updateHomework, .setHomeworkCompletion,
            .updateTodo:
            return "PATCH"
        case .deleteHomework, .deleteTodo, .removeCommentReaction:
            return "DELETE"
        }
    }

    var path: String {
        switch self {
        case .me:
            return "/api/me"
        case .listSemesters:
            return "/api/semesters"
        case .currentSemester:
            return "/api/semesters/current"
        case .listCourses:
            return "/api/courses"
        case .getCourse(let jwId):
            return "/api/courses/\(jwId)"
        case .listSections:
            return "/api/sections"
        case .getSection(let jwId):
            return "/api/sections/\(jwId)"
        case .getSectionSchedules(let jwId):
            return "/api/sections/\(jwId)/schedules"
        case .matchCodes:
            return "/api/sections/match-codes"
        case .listTeachers:
            return "/api/teachers"
        case .getTeacher(let id):
            return "/api/teachers/\(id)"
        case .querySchedules:
            return "/api/schedules"
        case .getSubscriptions:
            return "/api/calendar-subscriptions/current"
        case .updateSubscriptions:
            return "/api/calendar-subscriptions"
        case .listCalendarEvents:
            return "/api/workspace/calendar/events"
        case .listYoungEvents:
            return "/api/catalog/young-events"
        case .getYoungEvent(let youngId):
            return "/api/catalog/young-events/\(Self.pathSegment(youngId))"
        case .listYoungOrganizers:
            return "/api/catalog/young-organizers"
        case .getYoungOrganizer(let organizerId):
            return "/api/catalog/young-organizers/\(Self.pathSegment(organizerId))"
        case .listYoungEventSubscriptions:
            return "/api/workspace/young-event-subscriptions"
        case .getYoungEventSubscription(let youngId),
             .updateYoungEventSubscription(let youngId, _):
            return "/api/workspace/young-event-subscriptions/\(Self.pathSegment(youngId))"
        case .listYoungOrganizerSubscriptions:
            return "/api/workspace/young-organizer-subscriptions"
        case .getYoungOrganizerSubscription(let organizerId),
             .updateYoungOrganizerSubscription(let organizerId, _):
            return "/api/workspace/young-organizer-subscriptions/\(Self.pathSegment(organizerId))"
        case .listYoungNotifications:
            return "/api/workspace/young-notifications"
        case .markYoungNotificationRead(let id):
            return "/api/workspace/young-notifications/\(Self.pathSegment(id))/read"
        case .overview:
            return "/api/me"
        case .listHomeworks, .createHomework:
            return "/api/homeworks"
        case .getHomework(let id):
            return "/api/homeworks/\(id)"
        case .updateHomework(let id, _):
            return "/api/homeworks/\(id)"
        case .deleteHomework(let id):
            return "/api/homeworks/\(id)"
        case .setHomeworkCompletion(let id, _):
            return "/api/homeworks/\(id)/completion"
        case .listTodos, .createTodo:
            return "/api/todos"
        case .updateTodo(let id, _):
            return "/api/todos/\(id)"
        case .deleteTodo(let id):
            return "/api/todos/\(id)"
        case .listComments, .createComment:
            return "/api/community/comments"
        case .listCommentReplies(let id, _, _):
            return "/api/community/comments/\(Self.pathSegment(id))/replies"
        case .addCommentReaction(let id, _), .removeCommentReaction(let id, _):
            return "/api/community/comments/\(Self.pathSegment(id))/reactions"
        case .busSchedule:
            return "/api/bus"
        case .metadata:
            return "/api/metadata"
        case .listUploads, .createUpload:
            return "/api/uploads"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listSemesters(let page, let pageSize):
            var items: [URLQueryItem] = []
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listCourses(let query, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "q", value: query)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listSections(let query, let semesterId, let courseId, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "q", value: query)) }
            if let semesterId { items.append(.init(name: "semesterId", value: "\(semesterId)")) }
            if let courseId { items.append(.init(name: "courseId", value: "\(courseId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listTeachers(let query, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "q", value: query)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .querySchedules(let sectionId, let teacherId, let room, let date, let weekday):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let room { items.append(.init(name: "room", value: room)) }
            if let date { items.append(.init(name: "date", value: date)) }
            if let weekday { items.append(.init(name: "weekday", value: "\(weekday)")) }
            return items.isEmpty ? nil : items
        case .listCalendarEvents(let dateFrom, let dateTo, let page, let pageSize):
            return [
                .init(name: "dateFrom", value: dateFrom),
                .init(name: "dateTo", value: dateTo),
                .init(name: "page", value: "\(page)"),
                .init(name: "pageSize", value: "\(pageSize)"),
            ]
        case .listYoungEvents(
            let dateUnknown, let active, let category, let search, let organizerId,
            let dateFrom, let dateTo, let timeBasis, let page, let pageSize
        ):
            var items: [URLQueryItem] = []
            if let dateUnknown { items.append(.init(name: "dateUnknown", value: dateUnknown ? "true" : "false")) }
            if let active { items.append(.init(name: "active", value: active ? "true" : "false")) }
            if let category { items.append(.init(name: "category", value: category)) }
            if let search { items.append(.init(name: "search", value: search)) }
            if let organizerId { items.append(.init(name: "organizerId", value: organizerId)) }
            if let dateFrom { items.append(.init(name: "dateFrom", value: dateFrom)) }
            if let dateTo { items.append(.init(name: "dateTo", value: dateTo)) }
            if let timeBasis { items.append(.init(name: "timeBasis", value: timeBasis.rawValue)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listYoungOrganizers(let search, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let search { items.append(.init(name: "search", value: search)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listYoungEventSubscriptions(let page, let pageSize, let unread),
             .listYoungOrganizerSubscriptions(let page, let pageSize, let unread),
             .listYoungNotifications(let page, let pageSize, let unread):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            ]
            if let unread { items.append(.init(name: "unread", value: unread ? "true" : "false")) }
            return items
        case .listHomeworks(let sectionId, let subscribedOnly):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let subscribedOnly, subscribedOnly { items.append(.init(name: "subscribedOnly", value: "true")) }
            return items.isEmpty ? nil : items
        case .listComments(let targetType, let targetId, let youngId, let sectionId, let teacherId, let page, let pageSize):
            var items = [URLQueryItem(name: "targetType", value: targetType)]
            if let targetId { items.append(.init(name: "targetId", value: targetId)) }
            if let youngId { items.append(.init(name: "youngId", value: youngId)) }
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items
        case .listCommentReplies(_, let cursor, let pageSize):
            var items: [URLQueryItem] = []
            if let cursor { items.append(.init(name: "cursor", value: cursor)) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .removeCommentReaction(_, let type):
            return [.init(name: "type", value: type)]
        case .busSchedule(let origin, let dest, let dayType, let limit):
            var items: [URLQueryItem] = []
            if let origin { items.append(.init(name: "originCampusId", value: "\(origin)")) }
            if let dest { items.append(.init(name: "destinationCampusId", value: "\(dest)")) }
            if let dayType { items.append(.init(name: "dayType", value: dayType)) }
            if let limit { items.append(.init(name: "limit", value: "\(limit)")) }
            return items.isEmpty ? nil : items
        default:
            return nil
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .matchCodes(let req): return req
        case .updateSubscriptions(let req): return req
        case .updateYoungEventSubscription(_, let req): return req
        case .updateYoungOrganizerSubscription(_, let req): return req
        case .createHomework(let req): return req
        case .updateHomework(_, let req): return req
        case .setHomeworkCompletion(_, let req): return req
        case .createTodo(let req): return req
        case .updateTodo(_, let req): return req
        case .createComment(let req): return req
        case .addCommentReaction(_, let req): return req
        case .createUpload(let req): return req
        default: return nil
        }
    }

    // MARK: - Build URLRequest

    func buildURLRequest(baseURL: URL) -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.percentEncodedPath.hasSuffix("/")
            ? String(components.percentEncodedPath.dropLast())
            : components.percentEncodedPath
        components.percentEncodedPath = basePath + path
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        return request
    }

    private static func pathSegment(_ value: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

// MARK: - Type-erased Encodable wrapper

extension ServerEndpoint {
    /// Workspace calendar events are returned by the complete date-range endpoint.
}

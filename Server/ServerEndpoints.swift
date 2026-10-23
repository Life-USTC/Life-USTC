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
    case listSections(query: String?, semesterId: Int?, courseId: Int?, teacherId: Int? = nil, page: Int?, pageSize: Int?)
    case getSection(jwId: String)
    case getSectionSchedules(jwId: String, page: Int? = nil, pageSize: Int? = nil)
    case matchCodes(MatchCodesRequest)

    // Teachers
    case listTeachers(query: String?, page: Int?, pageSize: Int?)
    case getTeacher(id: Int)

    // Schedules
    case querySchedules(sectionId: Int?, teacherId: Int?, roomId: Int?, dateFrom: String?, dateTo: String?, weekday: Int?)

    // Calendar Subscriptions
    case getSubscriptions
    case importSubscriptions(MatchCodesRequest)
    case appendSubscriptions(SectionSubscriptionRequest)
    case removeSubscriptions(SectionSubscriptionRequest)
    case setSubscriptionKind(jwId: Int, SubscriptionKindRequest)

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
    case listHomeworks(sectionId: Int?, page: Int?, pageSize: Int?)
    case listSubscribedHomeworks(page: Int?, pageSize: Int?)
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
    case updateComment(id: String, UpdateCommentRequest)
    case deleteComment(id: String)
    case listCommentReplies(id: String, cursor: String?, pageSize: Int?)
    case addCommentReaction(id: String, CommentReactionRequest)
    case removeCommentReaction(id: String, type: String)

    // Bus
    case busSchedule(versionKey: String?)

    // Metadata
    case metadata

    // Uploads
    case listUploads(page: Int?, pageSize: Int?)
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
            .listHomeworks, .listSubscribedHomeworks, .getHomework, .listTodos,
            .listComments, .listCommentReplies,
            .busSchedule, .metadata, .listUploads:
            return "GET"
        case .matchCodes, .importSubscriptions, .createHomework,
            .createTodo, .createComment, .addCommentReaction,
            .markYoungNotificationRead, .createUpload:
            return "POST"
        case .updateYoungEventSubscription, .updateYoungOrganizerSubscription, .setHomeworkCompletion:
            return "PUT"
        case .updateHomework,
            .updateTodo, .updateComment, .appendSubscriptions, .setSubscriptionKind:
            return "PATCH"
        case .deleteHomework, .deleteTodo, .deleteComment, .removeCommentReaction, .removeSubscriptions:
            return "DELETE"
        }
    }

    var path: String {
        switch self {
        case .me:
            return "/api/account/profile"
        case .listSemesters:
            return "/api/catalog/semesters"
        case .currentSemester:
            return "/api/catalog/semesters/current"
        case .listCourses:
            return "/api/catalog/courses"
        case .getCourse(let jwId):
            return "/api/catalog/courses/\(Self.pathSegment(jwId))"
        case .listSections:
            return "/api/catalog/sections"
        case .getSection(let jwId):
            return "/api/catalog/sections/\(Self.pathSegment(jwId))"
        case .getSectionSchedules(let jwId, _, _):
            return "/api/catalog/sections/\(Self.pathSegment(jwId))/schedules"
        case .matchCodes:
            return "/api/catalog/sections/match-codes"
        case .listTeachers:
            return "/api/catalog/teachers"
        case .getTeacher(let id):
            return "/api/catalog/teachers/\(id)"
        case .querySchedules:
            return "/api/catalog/schedules"
        case .getSubscriptions:
            return "/api/workspace/subscriptions/current"
        case .appendSubscriptions, .removeSubscriptions:
            return "/api/workspace/subscriptions"
        case .setSubscriptionKind(let jwId, _):
            return "/api/workspace/subscriptions/\(jwId)"
        case .importSubscriptions:
            return "/api/workspace/subscriptions/import-codes"
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
            return "/api/workspace/overview"
        case .listHomeworks, .createHomework:
            return "/api/community/section-homeworks"
        case .listSubscribedHomeworks:
            return "/api/workspace/homeworks"
        case .getHomework(let id):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .updateHomework(let id, _):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .deleteHomework(let id):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .setHomeworkCompletion(let id, _):
            return "/api/workspace/homeworks/\(Self.pathSegment(id))/completion"
        case .listTodos, .createTodo:
            return "/api/workspace/todos"
        case .updateTodo(let id, _):
            return "/api/workspace/todos/\(Self.pathSegment(id))"
        case .deleteTodo(let id):
            return "/api/workspace/todos/\(Self.pathSegment(id))"
        case .listComments, .createComment:
            return "/api/community/comments"
        case .updateComment(let id, _), .deleteComment(let id):
            return "/api/community/comments/\(Self.pathSegment(id))"
        case .listCommentReplies(let id, _, _):
            return "/api/community/comments/\(Self.pathSegment(id))/replies"
        case .addCommentReaction(let id, _), .removeCommentReaction(let id, _):
            return "/api/community/comments/\(Self.pathSegment(id))/reactions"
        case .busSchedule:
            return "/api/catalog/bus"
        case .metadata:
            return "/api/catalog/metadata"
        case .listUploads, .createUpload:
            return "/api/workspace/uploads"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listSemesters(let page, let pageSize),
             .listSubscribedHomeworks(let page, let pageSize),
             .listUploads(let page, let pageSize):
            var items: [URLQueryItem] = []
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listCourses(let query, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "search", value: query)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listSections(let query, let semesterId, let courseId, let teacherId, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "search", value: query)) }
            if let semesterId { items.append(.init(name: "semesterId", value: "\(semesterId)")) }
            if let courseId { items.append(.init(name: "courseId", value: "\(courseId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listTeachers(let query, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "search", value: query)) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .getSection:
            return [
                .init(name: "includeSchedules", value: "true"),
                .init(name: "includeExams", value: "true"),
            ]
        case .getSectionSchedules(_, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .querySchedules(let sectionId, let teacherId, let roomId, let dateFrom, let dateTo, let weekday):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let roomId { items.append(.init(name: "roomId", value: "\(roomId)")) }
            if let dateFrom { items.append(.init(name: "dateFrom", value: dateFrom)) }
            if let dateTo { items.append(.init(name: "dateTo", value: dateTo)) }
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
        case .listHomeworks(let sectionId, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
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
        case .busSchedule(let versionKey):
            return versionKey.map { [.init(name: "versionKey", value: $0)] }
        default:
            return nil
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .matchCodes(let req): return req
        case .importSubscriptions(let req): return req
        case .appendSubscriptions(let req), .removeSubscriptions(let req): return req
        case .setSubscriptionKind(_, let req): return req
        case .updateYoungEventSubscription(_, let req): return req
        case .updateYoungOrganizerSubscription(_, let req): return req
        case .createHomework(let req): return req
        case .updateHomework(_, let req): return req
        case .setHomeworkCompletion(_, let req): return req
        case .createTodo(let req): return req
        case .updateTodo(_, let req): return req
        case .createComment(let req): return req
        case .updateComment(_, let req): return req
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

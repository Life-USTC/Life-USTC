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
    case listCalendarEvents(from: String, to: String)

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
        sectionId: Int?, teacherId: Int?
    )
    case createComment(CreateCommentRequest)

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
            .overview,
            .listHomeworks, .getHomework, .listTodos,
            .listComments,
            .busSchedule, .metadata, .listUploads:
            return "GET"
        case .matchCodes, .updateSubscriptions, .createHomework,
            .createTodo, .createComment, .createUpload:
            return "POST"
        case .updateHomework, .setHomeworkCompletion,
            .updateTodo:
            return "PATCH"
        case .deleteHomework, .deleteTodo:
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
            return "/api/calendar-subscriptions/current"
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
            return "/api/comments"
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
        case .listCalendarEvents(let from, let to):
            return [
                .init(name: "from", value: from),
                .init(name: "to", value: to),
            ]
        case .listHomeworks(let sectionId, let subscribedOnly):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let subscribedOnly, subscribedOnly { items.append(.init(name: "subscribedOnly", value: "true")) }
            return items.isEmpty ? nil : items
        case .listComments(let targetType, let targetId, let sectionId, let teacherId):
            var items = [URLQueryItem(name: "targetType", value: targetType)]
            if let targetId { items.append(.init(name: "targetId", value: targetId)) }
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            return items
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
        case .createHomework(let req): return req
        case .updateHomework(_, let req): return req
        case .setHomeworkCompletion(_, let req): return req
        case .createTodo(let req): return req
        case .updateTodo(_, let req): return req
        case .createComment(let req): return req
        case .createUpload(let req): return req
        default: return nil
        }
    }

    // MARK: - Build URLRequest

    func buildURLRequest(baseURL: URL) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        return request
    }
}

// MARK: - Type-erased Encodable wrapper

extension ServerEndpoint {
    /// Calendar events reuse the subscriptions endpoint with date range query params.
    /// The `overview` endpoint reuses `/api/me` — the response includes the user profile;
    /// future server changes may add overview data to this or a dedicated endpoint.
}

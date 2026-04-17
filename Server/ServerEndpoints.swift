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
    case currentSemester

    // Sections
    case matchCodes(MatchCodesRequest)

    // Calendar Subscriptions
    case getSubscriptions
    case updateSubscriptions(UpdateSubscriptionRequest)

    // Homeworks
    case listHomeworks(sectionId: Int)
    case createHomework(CreateHomeworkRequest)
    case updateHomework(id: String, body: [String: Any])
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
        case .me, .currentSemester, .getSubscriptions,
            .listHomeworks, .listTodos, .listComments,
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
        case .currentSemester:
            return "/api/semesters/current"
        case .matchCodes:
            return "/api/sections/match-codes"
        case .getSubscriptions:
            return "/api/calendar-subscriptions/current"
        case .updateSubscriptions:
            return "/api/calendar-subscriptions"
        case .listHomeworks:
            return "/api/homeworks"
        case .createHomework:
            return "/api/homeworks"
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
        case .listHomeworks(let sectionId):
            return [URLQueryItem(name: "sectionId", value: "\(sectionId)")]
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
    /// Handle the `updateHomework` case which uses [String: Any].
    /// For structured requests, use the typed body property above.
}

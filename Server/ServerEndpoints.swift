//
//  ServerEndpoints.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation
import LifeClientCore

// MARK: - Endpoint Definition

enum ServerEndpoint {
    // User
    case me
    case clientActivity(cursor: String?, limit: Int)
    case getPublicUser(identifier: String)

    // Shared descriptions
    case getDescription(target: ServerDescriptionTarget)
    case upsertDescription(ServerDescriptionUpsertRequest)

    // Semesters
    case listSemesters(page: Int?, pageSize: Int?)
    case currentSemester
    case catalogMetadata

    // Courses
    case listCourses(query: String?, educationLevelId: Int? = nil, page: Int?, pageSize: Int?)
    case getCourse(jwId: String)
    case courseSectionHistory(jwId: Int, page: Int, pageSize: Int)
    case teacherSectionHistory(id: Int, page: Int, pageSize: Int)

    // Sections
    case listSections(query: String?, semesterId: Int?, courseId: Int?, teacherId: Int? = nil, page: Int?, pageSize: Int?)
    case getSection(jwId: String)
    case getSectionSchedules(jwId: String, page: Int? = nil, pageSize: Int? = nil)
    case matchCodes(MatchCodesRequest)

    // Teachers
    case listTeachers(query: String?, page: Int?, pageSize: Int?)
    case getTeacher(id: Int)

    // Schedules
    case querySchedules(
        sectionId: Int?, teacherId: Int?, roomId: Int?, dateFrom: String?, dateTo: String?, weekday: Int?,
        sectionJwId: Int? = nil, sectionCode: String? = nil, teacherCode: String? = nil, roomJwId: Int? = nil,
        page: Int? = nil, pageSize: Int? = nil, locale: String? = nil
    )

    // Calendar Subscriptions
    case getSubscriptions
    case importSubscriptions(MatchCodesRequest)
    case querySubscriptionCodes(MatchCodesRequest, locale: String)
    case appendMatchedSubscriptions(SubscriptionBatchAddRequest, locale: String)
    case appendSubscriptions(SectionSubscriptionRequest)
    case removeSubscriptions(SectionSubscriptionRequest)
    case setSubscriptionKind(jwId: Int, SubscriptionKindRequest)

    // Calendar Events
    case listCalendarEvents(dateFrom: String, dateTo: String, page: Int, pageSize: Int)

    // Second Classroom (public catalog)
    case listYoungEvents(query: YoungEventQuery, page: Int?, pageSize: Int?)
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
    case actionableOverview(atTime: String?, locale: String?)

    // Personal exams
    case listSubscribedExams(page: Int, pageSize: Int, filters: ServerExamFilters)

    // Homeworks
    case listHomeworks(sectionId: Int?, page: Int?, pageSize: Int?,
                       sectionJwId: Int? = nil, sectionIds: [Int]? = nil, includeDeleted: Bool? = nil)
    case listSubscribedHomeworks(page: Int?, pageSize: Int?)
    case getHomework(id: String)
    case listHomeworkAudit(sectionJwId: Int)
    case createHomework(CreateHomeworkRequest)
    case updateHomework(id: String, UpdateHomeworkRequest)
    case deleteHomework(id: String)
    case setHomeworkCompletion(id: String, HomeworkCompletionRequest)

    // Todos
    case listTodos
    case listTodosPage(page: Int, pageSize: Int, filters: ServerTodoFilters)
    case createTodo(CreateTodoRequest)
    case updateTodo(id: String, UpdateTodoRequest)
    case deleteTodo(id: String)

    // Comments
    case listComments(
        targetType: String, targetId: String?,
        youngId: String?, sectionId: Int?, teacherId: Int?,
        page: Int?, pageSize: Int?,
        sectionJwId: Int? = nil, courseJwId: Int? = nil,
        homeworkId: String? = nil, sectionTeacherId: Int? = nil
    )
    case createComment(CreateCommentRequest)
    case getComment(id: String)
    case updateComment(id: String, UpdateCommentRequest)
    case deleteComment(id: String)
    case listCommentReplies(id: String, cursor: String?, pageSize: Int?)
    case addCommentReaction(id: String, CommentReactionRequest)
    case removeCommentReaction(id: String, type: String)

    // Bus
    case busSchedule(versionKey: String?)
    case busRoutes(origin: Int?, destination: Int?, versionKey: String?, locale: String)
    case busNext(ServerBusNextQuery)
    case busPreferences
    case setBusPreferences(ServerBusPreference)

    // Campus discovery
    case campusLinks(locale: String)
    case linkPins
    case setLinkPins(ServerLinkPinBatchRequest)
    case campusWeather(ServerWeatherLocation)
    case roomMap(code: String)
    case campusSearch(query: String, locale: String)
    case listPublications(filters: ServerPublicationFilters, page: Int, pageSize: Int)
    case getPublication(id: String)
    case listPublicationSources

    // Metadata
    case metadata

    // Uploads
    case listUploads(page: Int?, pageSize: Int?)
    case createUpload(CreateUploadRequest)
    case completeUpload(CompleteUploadRequest)
    case renameUpload(id: String, request: RenameUploadRequest)
    case deleteUpload(id: String)
    case downloadUpload(id: String)

    // MARK: - Properties

    var method: String {
        switch self {
        case .me, .clientActivity, .getPublicUser, .getDescription, .getComment, .listHomeworkAudit, .downloadUpload,
            .currentSemester, .listSemesters, .catalogMetadata,
            .listCourses, .getCourse, .courseSectionHistory, .teacherSectionHistory,
            .listSections, .getSection, .getSectionSchedules,
            .listTeachers, .getTeacher,
            .querySchedules,
            .getSubscriptions, .listCalendarEvents,
            .listYoungEvents, .getYoungEvent, .listYoungOrganizers,
            .getYoungOrganizer, .listYoungEventSubscriptions,
            .getYoungEventSubscription, .listYoungOrganizerSubscriptions,
            .getYoungOrganizerSubscription, .listYoungNotifications,
            .overview, .actionableOverview, .listSubscribedExams, .listTodosPage,
            .listHomeworks, .listSubscribedHomeworks, .getHomework, .listTodos,
            .listComments, .listCommentReplies,
            .busSchedule, .busRoutes, .busNext, .busPreferences,
            .campusLinks, .linkPins, .campusWeather, .roomMap, .campusSearch,
            .listPublications, .getPublication, .listPublicationSources, .metadata, .listUploads:
            return "GET"
        case .matchCodes, .importSubscriptions, .querySubscriptionCodes, .appendMatchedSubscriptions, .createHomework,
            .createTodo, .createComment, .addCommentReaction,
            .markYoungNotificationRead, .createUpload, .completeUpload, .upsertDescription,
            .setLinkPins, .setBusPreferences:
            return "POST"
        case .updateYoungEventSubscription, .updateYoungOrganizerSubscription, .setHomeworkCompletion:
            return "PUT"
        case .updateHomework, .renameUpload,
            .updateTodo, .updateComment, .appendSubscriptions, .setSubscriptionKind:
            return "PATCH"
        case .deleteHomework, .deleteTodo, .deleteComment, .removeCommentReaction, .removeSubscriptions, .deleteUpload:
            return "DELETE"
        }
    }

    var path: String {
        switch self {
        case .me:
            return "/api/account/profile"
        case .clientActivity:
            return "/api/account/client-activity"
        case .getPublicUser(let identifier):
            return "/api/community/users/\(Self.pathSegment(identifier))"
        case .getDescription, .upsertDescription:
            return "/api/community/descriptions"
        case .listSemesters:
            return "/api/catalog/semesters"
        case .catalogMetadata:
            return "/api/catalog/metadata"
        case .currentSemester:
            return "/api/catalog/semesters/current"
        case .listCourses:
            return "/api/catalog/courses"
        case .getCourse(let jwId):
            return "/api/catalog/courses/\(Self.pathSegment(jwId))"
        case .courseSectionHistory(let jwId, _, _):
            return "/api/catalog/courses/\(jwId)/sections"
        case .teacherSectionHistory(let id, _, _):
            return "/api/catalog/teachers/\(id)/sections"
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
        case .querySubscriptionCodes:
            return "/api/workspace/subscriptions/query"
        case .appendMatchedSubscriptions:
            return "/api/workspace/subscriptions/batch"
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
        case .actionableOverview:
            return "/api/workspace/overview/actionable"
        case .listSubscribedExams:
            return "/api/workspace/exams"
        case .listHomeworks, .createHomework:
            return "/api/community/section-homeworks"
        case .listSubscribedHomeworks:
            return "/api/workspace/homeworks"
        case .getHomework(let id):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .listHomeworkAudit:
            return "/api/community/section-homeworks/audit"
        case .updateHomework(let id, _):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .deleteHomework(let id):
            return "/api/community/section-homeworks/\(Self.pathSegment(id))"
        case .setHomeworkCompletion(let id, _):
            return "/api/workspace/homeworks/\(Self.pathSegment(id))/completion"
        case .listTodos, .listTodosPage, .createTodo:
            return "/api/workspace/todos"
        case .updateTodo(let id, _):
            return "/api/workspace/todos/\(Self.pathSegment(id))"
        case .deleteTodo(let id):
            return "/api/workspace/todos/\(Self.pathSegment(id))"
        case .listComments, .createComment:
            return "/api/community/comments"
        case .getComment(let id), .updateComment(let id, _), .deleteComment(let id):
            return "/api/community/comments/\(Self.pathSegment(id))"
        case .listCommentReplies(let id, _, _):
            return "/api/community/comments/\(Self.pathSegment(id))/replies"
        case .addCommentReaction(let id, _), .removeCommentReaction(let id, _):
            return "/api/community/comments/\(Self.pathSegment(id))/reactions"
        case .busSchedule:
            return "/api/catalog/bus"
        case .busRoutes:
            return "/api/catalog/bus/routes"
        case .busNext:
            return "/api/catalog/bus/next"
        case .busPreferences, .setBusPreferences:
            return "/api/workspace/bus-preferences"
        case .campusLinks:
            return "/api/catalog/links"
        case .linkPins:
            return "/api/workspace/link-pins"
        case .setLinkPins:
            return "/api/workspace/link-pins/batch"
        case .campusWeather:
            return "/api/catalog/weather"
        case .roomMap(let code):
            return "/api/catalog/rooms/\(Self.pathSegment(code))/map"
        case .campusSearch:
            return "/api/search"
        case .listPublications:
            return "/api/publications"
        case .getPublication(let id):
            return "/api/publications/\(Self.pathSegment(id))"
        case .listPublicationSources:
            return "/api/publications/sources"
        case .metadata:
            return "/api/catalog/metadata"
        case .listUploads, .createUpload:
            return "/api/workspace/uploads"
        case .completeUpload:
            return "/api/workspace/uploads/complete"
        case .renameUpload(let id, _), .deleteUpload(let id):
            return "/api/workspace/uploads/\(Self.pathSegment(id))"
        case .downloadUpload(let id):
            return "/api/workspace/uploads/\(Self.pathSegment(id))/download"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .courseSectionHistory(_, let page, let pageSize), .teacherSectionHistory(_, let page, let pageSize):
            return [.init(name: "page", value: "\(page)"), .init(name: "pageSize", value: "\(pageSize)")]
        case .clientActivity(let cursor, let limit):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let cursor { items.append(.init(name: "cursor", value: cursor)) }
            return items
        case .getDescription(let target):
            return target.queryItems
        case .querySubscriptionCodes(_, let locale), .appendMatchedSubscriptions(_, let locale):
            return [.init(name: "locale", value: locale)]
        case .listHomeworkAudit(let sectionJwId):
            return [.init(name: "sectionJwId", value: String(sectionJwId))]
        case .actionableOverview(let atTime, let locale):
            var items: [URLQueryItem] = []
            if let atTime { items.append(.init(name: "atTime", value: atTime)) }
            if let locale { items.append(.init(name: "locale", value: locale)) }
            return items.isEmpty ? nil : items
        case .listTodosPage(let page, let pageSize, let filters):
            var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "pageSize", value: "\(pageSize)")]
            if let completed = filters.completed { items.append(.init(name: "completed", value: completed ? "true" : "false")) }
            if let priority = filters.priority { items.append(.init(name: "priority", value: priority.rawValue)) }
            if let before = filters.dueBefore { items.append(.init(name: "dueBefore", value: ISO8601DateFormatter().string(from: before))) }
            if let after = filters.dueAfter { items.append(.init(name: "dueAfter", value: ISO8601DateFormatter().string(from: after))) }
            return items
        case .listSubscribedExams(let page, let pageSize, let filters):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)"),
                URLQueryItem(name: "includeDateUnknown", value: filters.includeDateUnknown ? "true" : "false"),
            ]
            if let semesterID = filters.semesterID { items.append(.init(name: "semesterId", value: "\(semesterID)")) }
            if let dateFrom = filters.dateFrom { items.append(.init(name: "dateFrom", value: dateFrom)) }
            if let dateTo = filters.dateTo { items.append(.init(name: "dateTo", value: dateTo)) }
            if let locale = filters.locale { items.append(.init(name: "locale", value: locale)) }
            return items
        case .listSemesters(let page, let pageSize),
             .listSubscribedHomeworks(let page, let pageSize),
             .listUploads(let page, let pageSize):
            var items: [URLQueryItem] = []
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listCourses(let query, let educationLevelId, let page, let pageSize):
            var items: [URLQueryItem] = []
            if let query { items.append(.init(name: "search", value: query)) }
            if let educationLevelId { items.append(.init(name: "educationLevelId", value: "\(educationLevelId)")) }
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
        case .querySchedules(let sectionId, let teacherId, let roomId, let dateFrom, let dateTo, let weekday,
                             let sectionJwId, let sectionCode, let teacherCode, let roomJwId,
                             let page, let pageSize, let locale):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let roomId { items.append(.init(name: "roomId", value: "\(roomId)")) }
            if let dateFrom { items.append(.init(name: "dateFrom", value: dateFrom)) }
            if let dateTo { items.append(.init(name: "dateTo", value: dateTo)) }
            if let weekday { items.append(.init(name: "weekday", value: "\(weekday)")) }
            if let sectionJwId { items.append(.init(name: "sectionJwId", value: "\(sectionJwId)")) }
            if let sectionCode { items.append(.init(name: "sectionCode", value: sectionCode)) }
            if let teacherCode { items.append(.init(name: "teacherCode", value: teacherCode)) }
            if let roomJwId { items.append(.init(name: "roomJwId", value: "\(roomJwId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            if let locale { items.append(.init(name: "locale", value: locale)) }
            return items.isEmpty ? nil : items
        case .listCalendarEvents(let dateFrom, let dateTo, let page, let pageSize):
            return [
                .init(name: "dateFrom", value: dateFrom),
                .init(name: "dateTo", value: dateTo),
                .init(name: "page", value: "\(page)"),
                .init(name: "pageSize", value: "\(pageSize)"),
            ]
        case .listYoungEvents(let query, let page, let pageSize):
            let items = query.queryItems(page: page, pageSize: pageSize)
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
        case .listHomeworks(let sectionId, let page, let pageSize, let sectionJwId, let sectionIds, let includeDeleted):
            var items: [URLQueryItem] = []
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let sectionJwId { items.append(.init(name: "sectionJwId", value: String(sectionJwId))) }
            if let sectionIds { items.append(.init(name: "sectionIds", value: sectionIds.map(String.init).joined(separator: ","))) }
            if let includeDeleted { items.append(.init(name: "includeDeleted", value: includeDeleted ? "true" : "false")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            return items.isEmpty ? nil : items
        case .listComments(let targetType, let targetId, let youngId, let sectionId, let teacherId, let page, let pageSize, let sectionJwId, let courseJwId, let homeworkId, let sectionTeacherId):
            var items = [URLQueryItem(name: "targetType", value: targetType)]
            if let targetId { items.append(.init(name: "targetId", value: targetId)) }
            if let youngId { items.append(.init(name: "youngId", value: youngId)) }
            if let sectionId { items.append(.init(name: "sectionId", value: "\(sectionId)")) }
            if let teacherId { items.append(.init(name: "teacherId", value: "\(teacherId)")) }
            if let page { items.append(.init(name: "page", value: "\(page)")) }
            if let pageSize { items.append(.init(name: "pageSize", value: "\(pageSize)")) }
            if let sectionJwId { items.append(.init(name: "sectionJwId", value: String(sectionJwId))) }
            if let courseJwId { items.append(.init(name: "courseJwId", value: String(courseJwId))) }
            if let homeworkId { items.append(.init(name: "homeworkId", value: homeworkId)) }
            if let sectionTeacherId { items.append(.init(name: "sectionTeacherId", value: String(sectionTeacherId))) }
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
        case .busRoutes(let origin, let destination, let versionKey, let locale):
            var items = [URLQueryItem(name: "locale", value: locale)]
            if let origin { items.append(.init(name: "originCampusId", value: String(origin))) }
            if let destination { items.append(.init(name: "destinationCampusId", value: String(destination))) }
            if let versionKey { items.append(.init(name: "versionKey", value: versionKey)) }
            return items
        case .busNext(let query):
            var items = [
                URLQueryItem(name: "originCampusId", value: String(query.originCampusId)),
                .init(name: "destinationCampusId", value: String(query.destinationCampusId)),
                .init(name: "dayType", value: query.dayType),
                .init(name: "includeDeparted", value: query.includeDeparted ? "true" : "false"),
                .init(name: "limit", value: String(query.limit)),
                .init(name: "locale", value: query.locale),
            ]
            if let versionKey = query.versionKey { items.append(.init(name: "versionKey", value: versionKey)) }
            if let atTime = query.atTime { items.append(.init(name: "atTime", value: atTime)) }
            return items
        case .campusLinks(let locale):
            return [.init(name: "locale", value: locale)]
        case .campusWeather(let location):
            return [.init(name: "locationKey", value: location.rawValue)]
        case .campusSearch(let query, let locale):
            return [.init(name: "q", value: query), .init(name: "scope", value: "catalog"),
                    .init(name: "limit", value: "25"), .init(name: "locale", value: locale)]
        case .listPublications(let filters, let page, let pageSize):
            return filters.queryItems + [.init(name: "page", value: String(page)), .init(name: "pageSize", value: String(pageSize))]
        default:
            return nil
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .matchCodes(let req): return req
        case .importSubscriptions(let req): return req
        case .querySubscriptionCodes(let req, _): return req
        case .appendMatchedSubscriptions(let req, _): return req
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
        case .completeUpload(let req): return req
        case .renameUpload(_, let req): return req
        case .upsertDescription(let req): return req
        case .setLinkPins(let req): return req
        case .setBusPreferences(let req): return req
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
        // The server decodes query parameters as form data, where a bare plus means a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")

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

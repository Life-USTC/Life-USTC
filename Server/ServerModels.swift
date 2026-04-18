//
//  ServerModels.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation

// MARK: - Common

struct ServerErrorResponse: Codable {
    let error: String
    let reason: String?
}

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
}

struct SuccessResponse: Codable {
    let success: Bool
}

struct IDResponse: Codable {
    let id: String
}

// MARK: - Auth / User

struct ServerUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let image: String?
    let username: String?
    let isAdmin: Bool
}

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Semester

struct ServerSemester: Codable, Identifiable {
    let id: Int
    let jwId: Int?
    let code: String
    let nameCn: String
    let startDate: Date?
    let endDate: Date?
}

// MARK: - Section / Course

struct ServerSection: Codable, Identifiable {
    let id: Int
    let code: String
    let semesterId: Int
    let courseId: Int
}

struct MatchCodesRequest: Encodable {
    let codes: [String]
    let semesterId: Int?
}

struct MatchCodesResponse: Codable {
    let semester: ServerSemester
    let matchedCodes: [String]
    let unmatchedCodes: [String]
    let sections: [ServerSection]
    let total: Int
}

// MARK: - Calendar Subscription

struct CalendarSubscription: Codable {
    let userId: String
    let sections: [ServerSectionSummary]?
    let calendarPath: String?
    let calendarUrl: String?
    let note: String?
}

struct CalendarSubscriptionResponse: Codable {
    let subscription: CalendarSubscription?
}

struct UpdateSubscriptionRequest: Encodable {
    let sectionIds: [Int]
}

// MARK: - Homework

struct ServerHomeworkCreator: Codable {
    let id: String
    let name: String?
    let username: String?
    let image: String?
}

struct ServerDescription: Codable {
    let id: String
    let content: String
}

struct ServerHomeworkCompletion: Codable {
    let completedAt: Date?
}

struct ServerHomework: Codable, Identifiable {
    let id: String
    let sectionId: Int
    let title: String
    let isMajor: Bool
    let requiresTeam: Bool
    let publishedAt: Date?
    let submissionStartAt: Date?
    let submissionDueAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let description: ServerDescription?
    let createdBy: ServerHomeworkCreator?
    let completion: ServerHomeworkCompletion?
    let commentCount: Int?
}

struct ServerHomeworkViewer: Codable {
    let userId: String?
    let isAdmin: Bool
}

struct ServerHomeworkListResponse: Codable {
    let viewer: ServerHomeworkViewer?
    let homeworks: [ServerHomework]
}

struct HomeworkCompletionRequest: Encodable {
    let completed: Bool
}

struct HomeworkCompletionResponse: Codable {
    let completed: Bool
    let completedAt: Date?
}

struct CreateHomeworkRequest: Encodable {
    let sectionId: Int
    let title: String
    let description: String?
    let publishedAt: String?
    let submissionStartAt: String?
    let submissionDueAt: String?
    let isMajor: Bool?
    let requiresTeam: Bool?
}

struct UpdateHomeworkRequest: Encodable {
    let title: String?
    let description: String?
    let publishedAt: String?
    let submissionStartAt: String?
    let submissionDueAt: String?
    let isMajor: Bool?
    let requiresTeam: Bool?
}

// MARK: - Todo

enum TodoPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var iconName: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "arrow.up"
        }
    }
}

struct ServerTodo: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let content: String?
    let priority: TodoPriority
    let completed: Bool
    let dueAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct ServerTodoListResponse: Codable {
    let todos: [ServerTodo]
}

struct CreateTodoRequest: Encodable {
    let title: String
    let content: String?
    let priority: String?
    let dueAt: String?
}

struct UpdateTodoRequest: Encodable {
    let title: String?
    let content: String?
    let priority: String?
    let dueAt: String?
    let completed: Bool?
}

// MARK: - Comment

struct ServerCommentAuthor: Codable {
    let id: String
    let name: String?
    let username: String?
    let image: String?
}

struct ServerCommentReaction: Codable {
    let type: String
    let count: Int
    let hasReacted: Bool
}

struct ServerComment: Codable, Identifiable {
    let id: String
    let body: String
    let visibility: String
    let isAnonymous: Bool
    let createdAt: Date
    let updatedAt: Date
    let author: ServerCommentAuthor?
    let reactions: [ServerCommentReaction]?
    let children: [ServerComment]?
}

struct ServerCommentListResponse: Codable {
    let comments: [ServerComment]
    let hiddenCount: Int
    let viewer: ServerHomeworkViewer?
}

struct CreateCommentRequest: Encodable {
    let targetType: String
    let targetId: String?
    let sectionId: Int?
    let teacherId: Int?
    let body: String
    let visibility: String?
    let isAnonymous: Bool?
    let parentId: String?
}

// MARK: - Bus

struct ServerBusCampus: Codable, Identifiable {
    let id: Int
    let nameCn: String
    let nameEn: String?
    let namePrimary: String?
    let nameSecondary: String?
}

struct ServerBusRoute: Codable, Identifiable {
    let id: Int
    let nameCn: String?
    let nameEn: String?
    let descriptionPrimary: String?
    let descriptionSecondary: String?
    let stops: [ServerBusStop]?
}

struct ServerBusStop: Codable {
    let stopOrder: Int
    let campus: ServerBusCampus?
}

struct ServerBusStopTime: Codable {
    let stopOrder: Int
    let campusId: Int?
    let campusName: String?
    let time: String?
    let minutesSinceMidnight: Int?
    let isPassThrough: Bool?
}

struct ServerBusTrip: Codable, Identifiable {
    let id: Int
    let routeId: Int?
    let dayType: String?
    let position: Int?
    let stopTimes: [ServerBusStopTime]?
    let departureTime: String?
    let departureMinutes: Int?
    let arrivalTime: String?
    let arrivalMinutes: Int?
    let status: String?
    let minutesUntilDeparture: Int?
}

struct ServerBusMatch: Codable {
    let route: ServerBusRoute?
    let originStop: ServerBusStop?
    let destinationStop: ServerBusStop?
    let nextTrip: ServerBusTrip?
    let upcomingTrips: [ServerBusTrip]?
    let totalTrips: Int?
    let isRecommended: Bool?
}

struct ServerBusNotice: Codable {
    let message: String?
    let url: String?
}

struct ServerBusResponse: Codable {
    let locale: String?
    let now: String?
    let todayType: String?
    let campuses: [ServerBusCampus]?
    let routes: [ServerBusRoute]?
    let matches: [ServerBusMatch]?
    let recommended: ServerBusMatch?
    let notice: ServerBusNotice?
}

// MARK: - Metadata

struct ServerMetadataResponse: Codable {
    let educationLevels: [MetadataItem]?
    let courseCategories: [MetadataItem]?
    let classTypes: [MetadataItem]?
    let campuses: [ServerCampus]?
}

struct MetadataItem: Codable, Identifiable {
    let id: Int
    let nameCn: String
    let nameEn: String?
}

struct ServerCampus: Codable, Identifiable {
    let id: Int
    let nameCn: String
    let nameEn: String?
}

// MARK: - Upload

struct ServerUpload: Codable, Identifiable {
    let id: String
    let key: String
    let filename: String
    let size: Int
    let createdAt: Date
}

struct ServerUploadListResponse: Codable {
    let maxFileSizeBytes: Int
    let quotaBytes: Int
    let uploads: [ServerUpload]
    let usedBytes: Int
}

struct CreateUploadRequest: Encodable {
    let filename: String
    let contentType: String?
    let size: Int
}

struct CreateUploadResponse: Codable {
    let key: String
    let url: String
    let maxFileSizeBytes: Int
    let quotaBytes: Int
    let usedBytes: Int
}

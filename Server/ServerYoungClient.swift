//
//  ServerYoungClient.swift
//  Life@USTC
//
//  Client helpers for public Second Classroom and private workspace APIs.
//

import Foundation

extension ServerClient {
    private func fetchAllPages<T: Codable>(
        _ load: (Int, Int) async throws -> PaginatedResponse<T>
    ) async throws -> [T] {
        var page = 1
        var values: [T] = []

        while true {
            let response = try await load(page, 100)
            values.append(contentsOf: response.data)

            if response.pagination.page >= response.pagination.totalPages {
                return values
            }

            let nextPage = response.pagination.page + 1
            guard nextPage > page else {
                throw ServerError.serverError("Invalid pagination response")
            }
            page = nextPage
        }
    }

    // MARK: - Public catalog

    func fetchYoungEvents(
        dateUnknown: Bool? = nil,
        active: Bool? = nil,
        category: String? = nil,
        search: String? = nil,
        organizerId: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        timeBasis: YoungEventTimeBasis? = nil
    ) async throws -> [ServerYoungEvent] {
        let page = try await fetchYoungEventsPage(
            dateUnknown: dateUnknown,
            active: active,
            category: category,
            search: search,
            organizerId: organizerId,
            dateFrom: dateFrom,
            dateTo: dateTo,
            timeBasis: timeBasis
        )
        return page.data
    }

    func fetchYoungEventsPage(
        dateUnknown: Bool? = nil,
        active: Bool? = nil,
        category: String? = nil,
        search: String? = nil,
        organizerId: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        timeBasis: YoungEventTimeBasis? = nil
    ) async throws -> ServerYoungEventsPage {
        var page = 1
        let firstResponse: ServerYoungEventsPage = try await request(
            .listYoungEvents(
                dateUnknown: dateUnknown,
                active: active,
                category: category,
                search: search,
                organizerId: organizerId,
                dateFrom: dateFrom,
                dateTo: dateTo,
                timeBasis: timeBasis,
                page: page,
                pageSize: 100
            )
        )
        var events = firstResponse.data
        while page < firstResponse.pagination.totalPages {
            page += 1
            let next: ServerYoungEventsPage = try await request(
                .listYoungEvents(
                    dateUnknown: dateUnknown,
                    active: active,
                    category: category,
                    search: search,
                    organizerId: organizerId,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    timeBasis: timeBasis,
                    page: page,
                    pageSize: 100
                )
            )
            events.append(contentsOf: next.data)
        }
        return ServerYoungEventsPage(
            data: events,
            pagination: firstResponse.pagination,
            unknownDateCount: firstResponse.unknownDateCount,
            source: firstResponse.source
        )
    }

    func fetchYoungEvent(youngId: String) async throws -> ServerYoungEvent {
        try await request(.getYoungEvent(youngId: youngId))
    }

    func fetchYoungOrganizers(search: String? = nil) async throws -> [ServerYoungOrganizer] {
        try await fetchAllPages { page, pageSize in
            try await request(
                .listYoungOrganizers(search: search, page: page, pageSize: pageSize)
            )
        }
    }

    func fetchYoungOrganizer(organizerId: String) async throws -> ServerYoungOrganizer {
        try await request(.getYoungOrganizer(organizerId: organizerId))
    }

    // MARK: - Complete personal calendar

    func fetchPersonalCalendarEvents(
        dateFrom: String,
        dateTo: String
    ) async throws -> [ServerPersonalCalendarEvent] {
        try await fetchAllPages { page, pageSize in
            try await request(
                .listCalendarEvents(
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    page: page,
                    pageSize: pageSize
                )
            )
        }
    }

    // MARK: - Event subscriptions

    func fetchYoungEventSubscriptions() async throws -> [ServerYoungEventSubscription] {
        try await fetchAllPages { page, pageSize in
            try await request(
                .listYoungEventSubscriptions(page: page, pageSize: pageSize, unread: nil)
            )
        }
    }

    func fetchYoungEventSubscription(
        youngId: String
    ) async throws -> ServerYoungEventSubscriptionState {
        try await request(.getYoungEventSubscription(youngId: youngId))
    }

    func updateYoungEventSubscription(
        youngId: String,
        subscribed: Bool,
        remindSignup: Bool,
        remindDeadline: Bool,
        remindStart: Bool
    ) async throws -> ServerYoungEventSubscriptionState {
        try await request(
            .updateYoungEventSubscription(
                youngId: youngId,
                YoungEventSubscriptionRequest(
                    subscribed: subscribed,
                    remindSignup: remindSignup,
                    remindDeadline: remindDeadline,
                    remindStart: remindStart
                )
            )
        )
    }

    // MARK: - Organizer subscriptions

    func fetchYoungOrganizerSubscriptions() async throws -> [ServerYoungOrganizerSubscription] {
        try await fetchAllPages { page, pageSize in
            try await request(
                .listYoungOrganizerSubscriptions(page: page, pageSize: pageSize, unread: nil)
            )
        }
    }

    func fetchYoungOrganizerSubscription(
        organizerId: String
    ) async throws -> ServerYoungOrganizerSubscriptionState {
        try await request(.getYoungOrganizerSubscription(organizerId: organizerId))
    }

    func updateYoungOrganizerSubscription(
        organizerId: String,
        subscribed: Bool
    ) async throws -> ServerYoungOrganizerSubscriptionState {
        try await request(
            .updateYoungOrganizerSubscription(
                organizerId: organizerId,
                YoungOrganizerSubscriptionRequest(subscribed: subscribed)
            )
        )
    }

    // MARK: - Notifications

    func fetchYoungNotifications() async throws -> [ServerYoungNotification] {
        try await fetchAllPages { page, pageSize in
            try await request(
                .listYoungNotifications(page: page, pageSize: pageSize, unread: nil)
            )
        }
    }

    func markYoungNotificationRead(id: String) async throws -> ServerYoungNotificationRead {
        try await request(.markYoungNotificationRead(id: id))
    }

    // MARK: - Community comments

    func fetchComments(
        targetType: String,
        targetId: String? = nil,
        youngId: String? = nil,
        sectionId: Int? = nil,
        teacherId: Int? = nil
    ) async throws -> ServerCommentListResponse {
        var page = 1
        let first: ServerCommentListResponse = try await request(
            .listComments(
                targetType: targetType,
                targetId: targetId,
                youngId: youngId,
                sectionId: sectionId,
                teacherId: teacherId,
                page: page,
                pageSize: 100
            )
        )
        var comments = first.data
        while page < first.pagination.totalPages {
            page += 1
            let response: ServerCommentListResponse = try await request(
                .listComments(
                    targetType: targetType,
                    targetId: targetId,
                    youngId: youngId,
                    sectionId: sectionId,
                    teacherId: teacherId,
                    page: page,
                    pageSize: 100
                )
            )
            comments.append(contentsOf: response.data)
        }
        return ServerCommentListResponse(
            data: comments,
            pagination: PaginationInfo(
                page: first.pagination.page,
                pageSize: first.pagination.pageSize,
                total: first.pagination.total,
                totalPages: first.pagination.totalPages
            ),
            meta: first.meta
        )
    }

    func fetchCommentReplies(
        id: String,
        cursor: String? = nil,
        pageSize: Int? = 20
    ) async throws -> ServerCommentRepliesResponse {
        try await request(
            .listCommentReplies(id: id, cursor: cursor, pageSize: pageSize)
        )
    }
}

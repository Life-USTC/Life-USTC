import Foundation

struct SectionSubscriptionRequest: Encodable {
    let sectionIds: [Int]
}

struct SubscriptionKindRequest: Encodable {
    let kind: ServerSubscriptionKind
}

struct SubscriptionKindResponse: Decodable {
    let sectionJwId: Int
    let kind: ServerSubscriptionKind
}

enum ServerCatalogSectionScope: Equatable {
    case course(Int)
    case teacher(Int)
}

struct ServerLearningSubscription: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let kind: ServerSubscriptionKind
    let course: ServerCourseSummary?
    let semester: ServerSemester?
    let teachers: [ServerTeacherRef]?
}

private struct LearningSubscriptionsResponse: Decodable {
    struct Subscription: Decodable {
        let sections: [ServerLearningSubscription]
    }
    let subscription: Subscription?
}

extension Notification.Name {
    static let serverSubscriptionsDidChange = Notification.Name("serverSubscriptionsDidChange")
}

extension ServerClient {
    func fetchAllCatalogSections(scope: ServerCatalogSectionScope) async throws -> [ServerSectionSummary] {
        let revision = sessionRevision
        let courseID: Int?
        let teacherID: Int?
        switch scope {
        case .course(let id):
            courseID = id
            teacherID = nil
        case .teacher(let id):
            courseID = nil
            teacherID = id
        }
        var sections: [ServerSectionSummary] = []
        var pageNumber = 1
        while true {
            try Task.checkCancellation()
            guard revision == sessionRevision else { throw CancellationError() }
            let page: PaginatedResponse<ServerSectionSummary> = try await request(
                .listSections(query: nil, semesterId: nil, courseId: courseID, teacherId: teacherID,
                              page: pageNumber, pageSize: 100),
                retry: true, expectedRevision: revision
            )
            try Task.checkCancellation()
            guard revision == sessionRevision else { throw CancellationError() }
            guard page.pagination.page == pageNumber, page.pagination.pageSize == 100,
                  page.pagination.totalPages >= 0, page.pagination.total >= 0,
                  page.data.count <= 100 else {
                throw ServerError.serverError("Invalid pagination response")
            }
            sections.append(contentsOf: page.data)
            guard pageNumber < page.pagination.totalPages else { return sections }
            pageNumber += 1
        }
    }

    func fetchAllSemesters() async throws -> [ServerSemester] {
        var semesters: [ServerSemester] = []
        var pageNumber = 1
        while true {
            try Task.checkCancellation()
            let page = try await fetchSemesters(page: pageNumber, pageSize: 100)
            semesters.append(contentsOf: page.data)
            guard pageNumber < page.pagination.totalPages else { return semesters }
            pageNumber += 1
        }
    }

    func fetchAllSectionSchedules(jwID: Int) async throws -> [ServerScheduleEntry] {
        var schedules: [ServerScheduleEntry] = []
        var pageNumber = 1
        while true {
            try Task.checkCancellation()
            let page: PaginatedResponse<ServerScheduleEntry> = try await request(
                .getSectionSchedules(jwId: String(jwID), page: pageNumber, pageSize: 100)
            )
            schedules.append(contentsOf: page.data)
            guard pageNumber < page.pagination.totalPages else { return schedules }
            pageNumber += 1
        }
    }

    func fetchLearningSubscriptions() async throws -> [ServerLearningSubscription] {
        let response: LearningSubscriptionsResponse = try await request(.getSubscriptions)
        return response.subscription?.sections ?? []
    }

    func appendSectionSubscription(sectionID: Int, expectedRevision: UUID? = nil) async throws {
        let revision = expectedRevision ?? sessionRevision
        let _: CalendarSubscriptionResponse = try await request(
            .appendSubscriptions(SectionSubscriptionRequest(sectionIds: [sectionID])),
            retry: true, expectedRevision: revision
        )
        try await MainActor.run {
            try Task.checkCancellation()
            guard revision == sessionRevision else { throw CancellationError() }
            NotificationCenter.default.post(name: .serverSubscriptionsDidChange, object: nil)
        }
    }

    func removeSectionSubscription(sectionID: Int, expectedRevision: UUID? = nil) async throws {
        let revision = expectedRevision ?? sessionRevision
        let _: CalendarSubscriptionResponse = try await request(
            .removeSubscriptions(SectionSubscriptionRequest(sectionIds: [sectionID])),
            retry: true, expectedRevision: revision
        )
        try await MainActor.run {
            try Task.checkCancellation()
            guard revision == sessionRevision else { throw CancellationError() }
            NotificationCenter.default.post(name: .serverSubscriptionsDidChange, object: nil)
        }
    }

    func updateSectionSubscriptionKind(jwID: Int, kind: ServerSubscriptionKind, expectedRevision: UUID? = nil) async throws {
        let revision = expectedRevision ?? sessionRevision
        let _: SubscriptionKindResponse = try await request(
            .setSubscriptionKind(jwId: jwID, SubscriptionKindRequest(kind: kind)),
            retry: true, expectedRevision: revision
        )
        try await MainActor.run {
            try Task.checkCancellation()
            guard revision == sessionRevision else { throw CancellationError() }
            NotificationCenter.default.post(name: .serverSubscriptionsDidChange, object: nil)
        }
    }
}

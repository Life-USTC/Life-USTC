import Foundation

extension Notification.Name {
    static let serverCommunityDidChange = Notification.Name("serverCommunityDidChange")
}

extension ServerClient {
    @MainActor
    private func notifyCommunityChanged(revision: UUID, workspace: Bool) throws {
        try Task.checkCancellation()
        guard revision == sessionRevision else { throw CancellationError() }
        NotificationCenter.default.post(name: .serverCommunityDidChange, object: nil)
        if workspace {
            NotificationCenter.default.post(name: .serverWorkspaceDidChange, object: nil)
        }
    }

    func fetchDescription(for target: ServerDescriptionTarget) async throws -> ServerDescriptionResponse {
        try await request(.getDescription(target: target))
    }

    func upsertDescription(
        for target: ServerDescriptionTarget, content: String, expectedRevision: UUID? = nil
    ) async throws -> ServerDescriptionUpsertResponse {
        let revision = expectedRevision ?? sessionRevision
        let response: ServerDescriptionUpsertResponse = try await request(
            .upsertDescription(ServerDescriptionUpsertRequest(target: target, content: content)),
            expectedRevision: revision
        )
        let updatesWorkspace: Bool
        if case .homework = target { updatesWorkspace = true }
        else { updatesWorkspace = false }
        try await notifyCommunityChanged(revision: revision, workspace: updatesWorkspace)
        return response
    }

    func fetchPublicUserProfile(identifier: String) async throws -> ServerPublicUserProfile {
        try await request(.getPublicUser(identifier: identifier))
    }

    func fetchCommentThread(id: String) async throws -> ServerCommentThreadResponse {
        try await request(.getComment(id: id))
    }

    func fetchHomeworkDetail(id: String) async throws -> ServerHomeworkDetailResponse {
        try await request(.getHomework(id: id))
    }

    func fetchSectionHomeworks(
        sectionJwId: Int, page: Int = 1, pageSize: Int = 50
    ) async throws -> ServerHomeworkListResponse {
        try await request(.listHomeworks(sectionId: nil, page: page, pageSize: pageSize, sectionJwId: sectionJwId))
    }

    func fetchHomeworkAudit(sectionJwId: Int) async throws -> [ServerHomeworkAuditLog] {
        let response: ServerHomeworkAuditResponse = try await request(.listHomeworkAudit(sectionJwId: sectionJwId))
        return response.auditLogs
    }

    func createHomework(_ input: CreateHomeworkRequest, expectedRevision: UUID? = nil) async throws -> ServerHomework {
        let revision = expectedRevision ?? sessionRevision
        let response: ServerHomeworkCreateResponse = try await request(.createHomework(input), expectedRevision: revision)
        try await notifyCommunityChanged(revision: revision, workspace: true)
        return response.homework
    }

    func updateHomework(
        id: String, request input: UpdateHomeworkRequest, expectedRevision: UUID? = nil
    ) async throws -> ServerHomework {
        let revision = expectedRevision ?? sessionRevision
        let response: ServerHomeworkUpdateResponse = try await request(.updateHomework(id: id, input), expectedRevision: revision)
        try await notifyCommunityChanged(revision: revision, workspace: true)
        return response.homework
    }

    func deleteHomework(id: String, expectedRevision: UUID? = nil) async throws {
        let revision = expectedRevision ?? sessionRevision
        let _: SuccessResponse = try await request(.deleteHomework(id: id), expectedRevision: revision)
        try await notifyCommunityChanged(revision: revision, workspace: true)
    }
}

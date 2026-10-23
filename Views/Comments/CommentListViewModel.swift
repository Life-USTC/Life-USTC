import SwiftUI

@Observable
@MainActor
final class CommentListViewModel {
    let targetType: String
    let targetId: String?
    let youngId: String?
    let sectionId: Int?
    let teacherId: Int?
    let sectionJwId: Int?
    let courseJwId: Int?
    let homeworkId: String?
    let sectionTeacherId: Int?
    let focusedCommentID: String?

    private(set) var isLoading = false
    private(set) var error: String?
    var mutationError: String?
    private(set) var loadingReplyIDs: Set<String> = []
    private(set) var replyErrors: [String: String] = [:]
    private(set) var mutatingIDs: Set<String> = []
    private var snapshot: [ServerComment] = []
    private var snapshotViewer: ServerCommentViewer?
    private var snapshotHiddenCount = 0
    private var loadedRevision: UUID?
    private var threadTarget: ServerCommentThreadTarget?
    private var permissionsResolved = false
    private var generation = 0
    private let client: ServerClient

    init(
        targetType: String, targetId: String? = nil, youngId: String? = nil,
        sectionId: Int? = nil, teacherId: Int? = nil,
        sectionJwId: Int? = nil, courseJwId: Int? = nil,
        homeworkId: String? = nil, sectionTeacherId: Int? = nil,
        focusedCommentID: String? = nil, client: ServerClient = .shared
    ) {
        self.targetType = targetType
        self.targetId = targetId
        self.youngId = youngId
        self.sectionId = sectionId
        self.teacherId = teacherId
        self.sectionJwId = sectionJwId
        self.courseJwId = courseJwId
        self.homeworkId = homeworkId
        self.sectionTeacherId = sectionTeacherId
        self.focusedCommentID = focusedCommentID
        self.client = client
    }

    var sessionRevision: UUID { client.sessionRevision }
    private var ownsSnapshot: Bool { loadedRevision == sessionRevision }
    var comments: [ServerComment] { ownsSnapshot ? snapshot : [] }
    var hiddenCount: Int { ownsSnapshot ? snapshotHiddenCount : 0 }
    var viewer: ServerCommentViewer? { ownsSnapshot ? snapshotViewer : nil }
    var canContribute: Bool {
        permissionsResolved && client.isAuthenticated && viewer?.isAuthenticated == true
            && viewer?.isSuspended == false
    }

    static func bodyValidationError(_ body: String) -> String? {
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return "Write a comment before posting.".localized }
        if body.utf16.count > 8_000 { return "Comments must be at most 8,000 characters.".localized }
        return nil
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = sessionRevision
        permissionsResolved = false
        loadingReplyIDs = []
        replyErrors = [:]
        if loadedRevision != revision {
            snapshot = []
            snapshotViewer = nil
            snapshotHiddenCount = 0
            threadTarget = nil
            replyErrors = [:]
            loadingReplyIDs = []
            mutatingIDs = []
            mutationError = nil
            loadedRevision = revision
        }
        isLoading = true
        error = nil
        defer { if requestGeneration == generation { isLoading = false } }
        do {
            if let focusedCommentID {
                let response: ServerCommentThreadResponse = try await client.request(
                    .getComment(id: focusedCommentID), expectedRevision: revision
                )
                guard requestGeneration == generation, revision == sessionRevision,
                      !Task.isCancelled else { return }
                snapshot = response.thread
                snapshotViewer = response.viewer
                snapshotHiddenCount = response.hiddenCount
                threadTarget = response.target
                permissionsResolved = true
                return
            }
            let response = try await client.fetchComments(
                targetType: targetType, targetId: targetId, youngId: youngId,
                sectionId: sectionId, teacherId: teacherId, sectionJwId: sectionJwId,
                courseJwId: courseJwId, homeworkId: homeworkId, sectionTeacherId: sectionTeacherId,
                expectedRevision: revision
            )
            guard requestGeneration == generation, revision == sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = response.comments
            snapshotViewer = response.meta.viewer
            snapshotHiddenCount = response.hiddenCount
            permissionsResolved = true
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func mutationRevision(_ expectedRevision: UUID? = nil) throws -> UUID {
        let revision = expectedRevision ?? sessionRevision
        guard revision == sessionRevision, ownsSnapshot else { throw CancellationError() }
        guard client.isAuthenticated else { throw ServerError.notAuthenticated }
        guard canContribute else { throw ServerError.forbidden("Comment action unavailable".localized) }
        return revision
    }

    private func publishMutation(revision: UUID) async throws {
        try Task.checkCancellation()
        guard revision == sessionRevision else { throw CancellationError() }
        NotificationCenter.default.post(name: .serverCommunityDidChange, object: nil)
        await load()
    }

    func createComment(
        body: String, visibility: String, isAnonymous: Bool, parentId: String?,
        attachmentIds: [String], expectedRevision: UUID
    ) async throws {
        let revision = try mutationRevision(expectedRevision)
        if let error = Self.bodyValidationError(body) { throw ServerError.badRequest(error) }
        let target = focusedCommentID == nil ? nil : threadTarget?.commentSelector
        if focusedCommentID != nil, target == nil {
            throw ServerError.badRequest("Comment target unavailable".localized)
        }
        let request = CreateCommentRequest(
            targetType: target?.type ?? targetType, targetId: target?.id ?? targetId, youngId: youngId, sectionId: sectionId,
            teacherId: teacherId, sectionJwId: sectionJwId, courseJwId: courseJwId,
            homeworkId: homeworkId, sectionTeacherId: sectionTeacherId,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines), visibility: visibility, isAnonymous: isAnonymous,
            parentId: parentId, attachmentIds: attachmentIds
        )
        mutationError = nil
        do {
            let _: IDResponse = try await client.request(.createComment(request), expectedRevision: revision)
            try await publishMutation(revision: revision)
        } catch {
            if revision == sessionRevision, !(error is CancellationError) {
                mutationError = error.localizedDescription
            }
            throw error
        }
    }

    func toggleReaction(commentId: String, reaction: ServerCommentReaction) async {
        guard !mutatingIDs.contains(commentId) else { return }
        let revision = sessionRevision
        do {
            _ = try mutationRevision(revision)
            mutatingIDs.insert(commentId)
            mutationError = nil
            defer { if revision == sessionRevision { mutatingIDs.remove(commentId) } }
            let endpoint: ServerEndpoint = reaction.hasReacted
                ? .removeCommentReaction(id: commentId, type: reaction.type)
                : .addCommentReaction(id: commentId, CommentReactionRequest(type: reaction.type))
            let _: SuccessResponse = try await client.request(endpoint, expectedRevision: revision)
            try await publishMutation(revision: revision)
        } catch {
            if revision == sessionRevision, !(error is CancellationError) {
                mutationError = error.localizedDescription
            }
        }
    }

    func updateComment(
        _ comment: ServerComment, body: String, visibility: String, isAnonymous: Bool,
        attachmentIds: [String]? = nil, expectedRevision: UUID? = nil
    ) async throws {
        let revision = try mutationRevision(expectedRevision)
        if let error = Self.bodyValidationError(body) { throw ServerError.badRequest(error) }
        mutationError = nil
        do {
            let _: ServerCommentUpdateResponse = try await client.request(
                .updateComment(id: comment.id, UpdateCommentRequest(
                    body: body.trimmingCharacters(in: .whitespacesAndNewlines), visibility: visibility, isAnonymous: isAnonymous,
                    attachmentIds: attachmentIds
                )), expectedRevision: revision
            )
            try await publishMutation(revision: revision)
        } catch {
            if revision == sessionRevision, !(error is CancellationError) {
                mutationError = error.localizedDescription
            }
            throw error
        }
    }

    func deleteComment(_ comment: ServerComment) async {
        guard !mutatingIDs.contains(comment.id) else { return }
        let revision = sessionRevision
        do {
            _ = try mutationRevision(revision)
            mutatingIDs.insert(comment.id)
            mutationError = nil
            defer { if revision == sessionRevision { mutatingIDs.remove(comment.id) } }
            let _: SuccessResponse = try await client.request(.deleteComment(id: comment.id), expectedRevision: revision)
            try await publishMutation(revision: revision)
        } catch {
            if revision == sessionRevision, !(error is CancellationError) {
                mutationError = error.localizedDescription
            }
        }
    }

    func loadMoreReplies(for comment: ServerComment) async {
        guard ownsSnapshot, let cursor = comment.repliesNextCursor,
              !loadingReplyIDs.contains(comment.id) else { return }
        let revision = sessionRevision
        let requestGeneration = generation
        loadingReplyIDs.insert(comment.id)
        replyErrors[comment.id] = nil
        defer {
            if revision == sessionRevision, requestGeneration == generation {
                loadingReplyIDs.remove(comment.id)
            }
        }
        do {
            let response: ServerCommentRepliesResponse = try await client.request(
                .listCommentReplies(id: comment.id, cursor: cursor, pageSize: 20), expectedRevision: revision
            )
            guard revision == sessionRevision, requestGeneration == generation,
                  !Task.isCancelled else { return }
            guard mergeReplyPage(response) else {
                throw ServerError.serverError("Reply thread was not returned by the server".localized)
            }
            snapshotViewer = response.viewer
        } catch {
            guard revision == sessionRevision, requestGeneration == generation,
                  !Task.isCancelled else { return }
            replyErrors[comment.id] = error.localizedDescription
        }
    }

    private func mergeReplyPage(_ response: ServerCommentRepliesResponse) -> Bool {
        guard let incomingRoot = response.thread.first(where: { $0.id == response.rootId }) else {
            return false
        }

        var mergedRoot = false
        func merge(_ node: ServerComment) -> ServerComment {
            if node.id == response.rootId {
                mergedRoot = true
                var replies = node.replies ?? []
                for incoming in incomingRoot.replies ?? [] {
                    if let index = replies.firstIndex(where: { $0.id == incoming.id }) {
                        replies[index] = mergeExistingReply(replies[index], incoming)
                    } else {
                        replies.append(incoming)
                    }
                }
                return incomingRoot.replacingReplies(replies, nextCursor: response.nextCursor)
            }

            guard let children = node.replies else { return node }
            let updatedChildren = children.map(merge)
            return node.replacingReplies(updatedChildren, nextCursor: node.repliesNextCursor)
        }

        snapshot = snapshot.map(merge)
        if mergedRoot {
            replyErrors[response.rootId] = nil
        }
        return mergedRoot
    }

    private func mergeExistingReply(
        _ existing: ServerComment,
        _ incoming: ServerComment
    ) -> ServerComment {
        var replies = existing.replies ?? []
        for incomingReply in incoming.replies ?? [] {
            if let index = replies.firstIndex(where: { $0.id == incomingReply.id }) {
                replies[index] = mergeExistingReply(replies[index], incomingReply)
            } else {
                replies.append(incomingReply)
            }
        }
        return incoming.replacingReplies(
            replies,
            nextCursor: incoming.repliesNextCursor ?? existing.repliesNextCursor
        )
    }
}


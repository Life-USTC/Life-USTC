import SwiftUI

@Observable
@MainActor
final class ServerSectionHomeworksModel {
    let sectionJwId: Int
    private let client: ServerClient
    private var loadedRevision: UUID?
    private var snapshot: [ServerHomework] = []
    private var viewerSnapshot: ServerHomeworkViewer?
    private var permissionsResolved = false
    private var generation = 0
    private var loading = false
    private var deletingID: String?
    private var loadingError: String?
    private var deletionError: String?
    private var failedDeletionID: String?
    private var confirmedDeletedIDs: Set<String> = []

    init(sectionJwId: Int, client: ServerClient = .shared) {
        self.sectionJwId = sectionJwId
        self.client = client
    }

    private var ownsSnapshot: Bool { loadedRevision == client.sessionRevision }
    var homeworks: [ServerHomework] { ownsSnapshot ? snapshot : [] }
    var viewer: ServerHomeworkViewer? { ownsSnapshot ? viewerSnapshot : nil }
    var isLoading: Bool { ownsSnapshot && loading }
    var mutatingID: String? { ownsSnapshot ? deletingID : nil }
    var loadError: String? { ownsSnapshot ? loadingError : nil }
    var deleteError: String? { ownsSnapshot ? deletionError : nil }
    var canCreate: Bool {
        ownsSnapshot && client.isAuthenticated && permissionsResolved && !loading && deletingID == nil
            && viewer?.isAuthenticated == true && viewer?.isSuspended == false
    }
    var canRetryDelete: Bool {
        guard let id = failedDeletionID, let homework = homeworks.first(where: { $0.id == id }) else { return false }
        return canDelete(homework)
    }

    func isDeleted(_ homework: ServerHomework) -> Bool {
        homework.deletedAt != nil || (ownsSnapshot && confirmedDeletedIDs.contains(homework.id))
    }

    func canEdit(_ homework: ServerHomework) -> Bool {
        canCreate && homeworks.contains(where: { $0.id == homework.id }) && !isDeleted(homework)
    }

    func canDelete(_ homework: ServerHomework) -> Bool {
        guard canEdit(homework), let userID = viewer?.userId else { return false }
        return (homework.createdById ?? homework.createdBy?.id) == userID
    }

    func load() async {
        resetForSessionIfNeeded()
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        permissionsResolved = false
        loading = true
        loadingError = nil
        defer {
            if requestGeneration == generation { loading = false }
            resetForSessionIfNeeded()
        }
        do {
            var items: [ServerHomework] = []
            var resolvedViewer: ServerHomeworkViewer?
            var page = 1
            var totalPages = 1
            repeat {
                let response: ServerHomeworkListResponse = try await client.request(
                    .listHomeworks(sectionId: nil, page: page, pageSize: 100,
                                   sectionJwId: sectionJwId, includeDeleted: true),
                    expectedRevision: revision
                )
                guard requestGeneration == generation, revision == client.sessionRevision,
                      !Task.isCancelled else { return }
                guard response.pagination.page == page, response.pagination.pageSize == 100,
                      response.pagination.totalPages >= 0, response.pagination.total >= 0,
                      response.data.count <= 100 else {
                    throw ServerError.serverError(String(localized: "The homework list could not be read completely."))
                }
                items.append(contentsOf: response.data)
                resolvedViewer = response.meta.viewer
                totalPages = response.pagination.totalPages
                page += 1
            } while page <= totalPages
            snapshot = items
            viewerSnapshot = resolvedViewer
            permissionsResolved = true
            confirmedDeletedIDs = confirmedDeletedIDs.filter { id in
                items.contains { $0.id == id && $0.deletedAt == nil }
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadingError = error.localizedDescription
        }
    }

    @discardableResult
    func delete(id: String) async -> Bool {
        guard let homework = homeworks.first(where: { $0.id == id }), canDelete(homework) else { return false }
        let revision = client.sessionRevision
        deletingID = id
        deletionError = nil
        failedDeletionID = nil
        defer {
            if revision == client.sessionRevision { deletingID = nil }
            resetForSessionIfNeeded()
        }
        do {
            try await client.deleteHomework(id: id, expectedRevision: revision)
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            confirmedDeletedIDs.insert(id)
            await load()
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            deletionError = error.localizedDescription
            failedDeletionID = id
            return false
        }
    }

    @discardableResult
    func retryDelete() async -> Bool {
        guard canRetryDelete, let failedDeletionID else { return false }
        return await delete(id: failedDeletionID)
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision else { return }
        loadedRevision = client.sessionRevision
        snapshot = []
        viewerSnapshot = nil
        permissionsResolved = false
        loading = false
        deletingID = nil
        loadingError = nil
        deletionError = nil
        failedDeletionID = nil
        confirmedDeletedIDs = []
    }
}

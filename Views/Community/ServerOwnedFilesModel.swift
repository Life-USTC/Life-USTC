import SwiftUI

@Observable
@MainActor
final class ServerOwnedFilesModel {
    private let client: ServerClient
    private var loadedRevision: UUID?
    private var snapshot: [ServerUpload] = []
    private var quotaSnapshot: ServerUploadQuota?
    private var loading = false
    private var refreshingQuota = false
    private var loadingError: String?
    private var quotaLoadingError: String?
    private var writeError: String?
    private var writingID: String?
    private var failedMutation: Mutation?
    private var previewSnapshot: ServerDownloadedUpload?
    private var previewID: String?
    private var downloadID: String?
    private var previewError: String?
    private var loadGeneration = 0
    private var quotaGeneration = 0
    private var downloadGeneration = 0

    private enum Mutation {
        case rename(id: String, filename: String)
        case delete(id: String)

        var id: String {
            switch self {
            case .rename(let id, _), .delete(let id): id
            }
        }
    }

    init(client: ServerClient = .shared) { self.client = client }


    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision
    }

    var uploads: [ServerUpload] { ownsSnapshot ? snapshot : [] }
    var quota: ServerUploadQuota? { ownsSnapshot ? quotaSnapshot : nil }
    var isLoading: Bool { ownsSnapshot && loading }
    var isRefreshingQuota: Bool { ownsSnapshot && refreshingQuota }
    var loadError: String? { ownsSnapshot ? loadingError : nil }
    var quotaError: String? { ownsSnapshot ? quotaLoadingError : nil }
    var mutationError: String? { ownsSnapshot ? writeError : nil }
    var mutatingID: String? { ownsSnapshot ? writingID : nil }
    var downloadingID: String? { ownsSnapshot ? downloadID : nil }
    var downloadError: String? { ownsSnapshot ? previewError : nil }
    var preview: ServerDownloadedUpload? {
        ownsSnapshot && previewSnapshot?.localURL != nil ? previewSnapshot : nil
    }
    var canRetryMutation: Bool {
        guard ownsSnapshot, writingID == nil, let failedMutation else { return false }
        return snapshot.contains { $0.id == failedMutation.id }
    }

    func load() async {
        resetForSessionIfNeeded()
        let revision = client.sessionRevision
        loadGeneration += 1
        let generation = loadGeneration
        quotaGeneration += 1
        refreshingQuota = false
        loadingError = nil
        loading = client.isAuthenticated
        guard client.isAuthenticated else { return }
        defer {
            if generation == loadGeneration { loading = false }
            resetForSessionIfNeeded()
        }
        do {
            let collection = try await client.fetchAllUploads()
            guard generation == loadGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = collection.uploads
            quotaSnapshot = collection.quota
            quotaLoadingError = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadingError = error.localizedDescription
        }
    }

    func refreshQuota() async {
        guard ownsSnapshot else { return }
        let revision = client.sessionRevision
        quotaGeneration += 1
        let generation = quotaGeneration
        refreshingQuota = true
        quotaLoadingError = nil
        defer {
            if generation == quotaGeneration { refreshingQuota = false }
            resetForSessionIfNeeded()
        }
        do {
            let page = try await client.fetchUploadsPage(page: 1, pageSize: 1)
            guard generation == quotaGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            quotaSnapshot = page.meta
        } catch is CancellationError {
            return
        } catch {
            guard generation == quotaGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            quotaLoadingError = error.localizedDescription
        }
    }

    @discardableResult
    func rename(id: String, filename: String) async -> Bool {
        await mutate(.rename(id: id, filename: filename))
    }

    @discardableResult
    func delete(id: String) async -> Bool {
        await mutate(.delete(id: id))
    }

    @discardableResult
    func retryMutation() async -> Bool {
        guard canRetryMutation, let failedMutation else { return false }
        return await mutate(failedMutation)
    }

    @discardableResult
    func download(id: String) async -> Bool {
        guard ownsSnapshot, let upload = snapshot.first(where: { $0.id == id }) else { return false }
        let revision = client.sessionRevision
        dismissPreview()
        let generation = downloadGeneration
        downloadID = id
        defer {
            if generation == downloadGeneration { downloadID = nil }
            resetForSessionIfNeeded()
        }
        do {
            let artifact = try await client.downloadUpload(
                id: id, filename: upload.filename, expectedRevision: revision
            )
            guard generation == downloadGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else {
                artifact.remove()
                return false
            }
            previewSnapshot = artifact
            previewID = id
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard generation == downloadGeneration, revision == client.sessionRevision,
                  !Task.isCancelled else { return false }
            previewError = error.localizedDescription
            return false
        }
    }

    func dismissPreview() {
        downloadGeneration += 1
        previewSnapshot?.remove()
        previewSnapshot = nil
        previewID = nil
        downloadID = nil
        previewError = nil
    }

    private func mutate(_ mutation: Mutation) async -> Bool {
        guard ownsSnapshot, writingID == nil,
              snapshot.contains(where: { $0.id == mutation.id }) else { return false }
        let revision = client.sessionRevision
        writingID = mutation.id
        writeError = nil
        failedMutation = nil
        defer {
            if revision == client.sessionRevision { writingID = nil }
            resetForSessionIfNeeded()
        }
        do {
            switch mutation {
            case .rename(let id, let filename):
                let renamed = try await client.renameUpload(
                    id: id, filename: filename, expectedRevision: revision
                )
                guard revision == client.sessionRevision, !Task.isCancelled else { return false }
                invalidateLoading()
                if let index = snapshot.firstIndex(where: { $0.id == id }) { snapshot[index] = renamed }
            case .delete(let id):
                _ = try await client.deleteUpload(id: id, expectedRevision: revision)
                guard revision == client.sessionRevision, !Task.isCancelled else { return false }
                invalidateLoading()
                snapshot.removeAll { $0.id == id }
                quotaSnapshot = nil
                if previewID == id || downloadID == id { dismissPreview() }
                await refreshQuota()
            }
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            writeError = error.localizedDescription
            failedMutation = mutation
            return false
        }
    }

    private func invalidateLoading() {
        loadGeneration += 1
        quotaGeneration += 1
        loading = false
        refreshingQuota = false
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision || !client.isAuthenticated else { return }
        loadedRevision = client.sessionRevision
        snapshot = []
        quotaSnapshot = nil
        loadingError = nil
        quotaLoadingError = nil
        writeError = nil
        writingID = nil
        failedMutation = nil
        invalidateLoading()
        dismissPreview()
    }
}

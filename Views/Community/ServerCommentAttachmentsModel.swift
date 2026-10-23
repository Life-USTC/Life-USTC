import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class ServerCommentAttachmentsModel {
    struct Draft: Identifiable {
        let id = UUID()
        let upload: ServerUploadDraft
        var error: String?
    }

    private let client: ServerClient
    private let revision: UUID
    private var invalidated = false
    private var existingSnapshot: [ServerCommentAttachment]
    private var draftSnapshot: [Draft] = []
    private var quotaSnapshot: ServerUploadQuota?
    private var loadingQuota = false
    private var importing = false
    private var errorSnapshot: String?

    init(existing: [ServerCommentAttachment] = [], client: ServerClient = .shared) {
        self.client = client
        revision = client.sessionRevision
        existingSnapshot = existing
    }

    var isCurrentSession: Bool {
        !invalidated && client.isAuthenticated && revision == client.sessionRevision
    }
    var existing: [ServerCommentAttachment] { isCurrentSession ? existingSnapshot : [] }
    var drafts: [Draft] { isCurrentSession ? draftSnapshot : [] }
    var quota: ServerUploadQuota? { isCurrentSession ? quotaSnapshot : nil }
    var error: String? { isCurrentSession ? errorSnapshot : nil }
    var isLoadingQuota: Bool { isCurrentSession && loadingQuota }
    var isBusy: Bool {
        isCurrentSession && (importing || draftSnapshot.contains { $0.upload.isUploading })
    }
    var canAdd: Bool { isCurrentSession && !isBusy && !loadingQuota && quotaSnapshot != nil }
    var canSubmit: Bool {
        isCurrentSession && !isBusy && draftSnapshot.allSatisfy { $0.upload.completion != nil }
    }

    func uploadIDsForSubmission() throws -> [String] {
        guard isCurrentSession else { throw CancellationError() }
        guard canSubmit else { throw ServerError.badRequest("Finish or remove pending attachments before posting.".localized) }
        return existingSnapshot.map(\.uploadId) + draftSnapshot.compactMap { $0.upload.completion?.upload.id }
    }

    func loadQuota() async {
        guard isCurrentSession, !loadingQuota else { return }
        loadingQuota = true
        defer { loadingQuota = false }
        do {
            _ = try await refreshQuota()
            errorSnapshot = nil
        } catch is CancellationError {
            return
        } catch {
            if isCurrentSession { errorSnapshot = error.localizedDescription }
        }
    }

    func importFile(_ url: URL) async {
        guard isCurrentSession, !isBusy else { return }
        importing = true
        errorSnapshot = nil
        defer { importing = false }
        do {
            let quota = try await refreshQuota()
            let document = try await Task.detached(priority: .userInitiated) {
                try Self.readDocument(url, quota: quota)
            }.value
            try requireCurrentSession()
            await appendAndUpload(data: document.data, filename: document.filename, contentType: document.contentType)
        } catch is CancellationError {
            return
        } catch {
            if isCurrentSession { errorSnapshot = error.localizedDescription }
        }
    }

    /// The same path as a document import, with bytes supplied by a caller or test.
    func add(data: Data, filename: String, contentType: String? = nil) async {
        guard isCurrentSession, !isBusy else { return }
        importing = true
        errorSnapshot = nil
        defer { importing = false }
        do {
            let quota = try await refreshQuota()
            try Self.validateSize(data.count, quota: quota)
            try requireCurrentSession()
            await appendAndUpload(data: data, filename: filename, contentType: contentType)
        } catch is CancellationError {
            return
        } catch {
            if isCurrentSession { errorSnapshot = error.localizedDescription }
        }
    }

    func retry(_ id: UUID) async {
        guard isCurrentSession, !isBusy else { return }
        await upload(id)
    }

    func removeExisting(_ id: String) {
        guard isCurrentSession, !isBusy else { return }
        existingSnapshot.removeAll { $0.id == id }
    }

    func removeDraft(_ id: UUID) {
        guard isCurrentSession, !isBusy else { return }
        draftSnapshot.removeAll { $0.id == id }
    }

    func reportImportError(_ error: Error) {
        guard isCurrentSession else { return }
        if (error as NSError).code == NSUserCancelledError { return }
        errorSnapshot = error.localizedDescription
    }

    func invalidateIfSessionChanged() {
        guard revision != client.sessionRevision || !client.isAuthenticated else { return }
        invalidated = true
        existingSnapshot = []
        draftSnapshot = []
        quotaSnapshot = nil
        errorSnapshot = nil
        loadingQuota = false
        importing = false
    }

    private func refreshQuota() async throws -> ServerUploadQuota {
        try requireCurrentSession()
        let response = try await client.fetchUploadsPage(page: 1, pageSize: 1)
        try requireCurrentSession()
        quotaSnapshot = response.meta
        return response.meta
    }

    private func appendAndUpload(data: Data, filename: String, contentType: String?) async {
        guard isCurrentSession else { return }
        let draft = Draft(upload: ServerUploadDraft(data: data, filename: filename, contentType: contentType))
        draftSnapshot.append(draft)
        await upload(draft.id)
    }

    private func upload(_ id: UUID) async {
        guard isCurrentSession, let index = draftSnapshot.firstIndex(where: { $0.id == id }) else { return }
        let draft = draftSnapshot[index].upload
        draftSnapshot[index].error = nil
        do {
            let completed = try await draft.upload(using: client)
            try requireCurrentSession()
            if let quotaSnapshot {
                self.quotaSnapshot = ServerUploadQuota(maxFileSizeBytes: quotaSnapshot.maxFileSizeBytes,
                                                       quotaBytes: completed.quotaBytes, usedBytes: completed.usedBytes)
            }
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession, let index = draftSnapshot.firstIndex(where: { $0.id == id }) else { return }
            draftSnapshot[index].error = error.localizedDescription
        }
    }

    private func requireCurrentSession() throws {
        try Task.checkCancellation()
        guard isCurrentSession else { throw CancellationError() }
    }

    nonisolated private static func validateSize(_ size: Int, quota: ServerUploadQuota) throws {
        guard size > 0 else { throw ServerError.badRequest("Choose a nonempty file.".localized) }
        guard size <= quota.maxFileSizeBytes else {
            throw ServerError.badRequest("This file exceeds the server's per-file limit.".localized)
        }
        guard size <= max(0, quota.quotaBytes - quota.usedBytes) else {
            throw ServerError.badRequest("There is not enough storage for this file.".localized)
        }
    }

    nonisolated private static func readDocument(_ url: URL, quota: ServerUploadQuota) throws
        -> (data: Data, filename: String, contentType: String?) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
        guard values.isRegularFile == true, let size = values.fileSize else {
            throw ServerError.badRequest("Choose a regular file.".localized)
        }
        try validateSize(size, quota: quota)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: size + 1) ?? Data()
        guard data.count == size else { throw ServerError.badRequest("The file changed while it was being read. Choose it again.".localized) }
        return (data, url.lastPathComponent, values.contentType?.preferredMIMEType)
    }
}

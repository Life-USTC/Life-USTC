import Foundation
import Observation

struct CompleteUploadRequest: Encodable {
    let key: String
    let filename: String
    let contentType: String?
}

struct RenameUploadRequest: Encodable {
    let filename: String
}

struct ServerUploadCompletionResponse: Decodable {
    let upload: ServerUpload
    let usedBytes: Int
    let quotaBytes: Int
}

struct ServerUploadRenameResponse: Decodable {
    let upload: ServerUpload
}

struct ServerUploadDeleteResponse: Decodable {
    let deletedId: String
    let deletedSize: Int
}

struct ServerUploadCollection {
    let uploads: [ServerUpload]
    let quota: ServerUploadQuota
}

struct ServerUploadReservation {
    let filename: String
    let contentType: String
    let size: Int
    let quota: ServerUploadQuota
    let key: String
    let objectURL: URL
    let revision: UUID
}

/// Retain the draft after a failure to retry only its unfinished upload phase.
@MainActor @Observable
final class ServerUploadDraft {
    let filename: String
    let contentType: String?
    let size: Int
    private(set) var isUploading = false

    var completion: ServerUploadCompletionResponse? {
        guard revision == ownerClient?.sessionRevision else { return nil }
        return completedResponse
    }

    private var data: Data?
    private var completedResponse: ServerUploadCompletionResponse?
    private weak var ownerClient: ServerClient?
    private var reservation: ServerUploadReservation?
    private var objectUploaded = false
    private var revision: UUID?

    init(data: Data, filename: String, contentType: String? = nil) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
        self.size = data.count
    }

    @discardableResult
    func upload(using client: ServerClient = .shared) async throws -> ServerUploadCompletionResponse {
        try Task.checkCancellation()
        if let revision, revision != client.sessionRevision { throw CancellationError() }
        if let completion { return completion }
        guard !isUploading else { throw ServerError.badRequest("Upload is already in progress") }
        isUploading = true
        defer { isUploading = false }
        if revision == nil {
            revision = client.sessionRevision
            ownerClient = client
        }
        if reservation == nil {
            reservation = try await client.reserveUpload(
                filename: filename, contentType: contentType, size: size, expectedRevision: revision
            )
        }
        guard let reservation, let data else { throw CancellationError() }
        if !objectUploaded {
            try await client.putUpload(data: data, reservation: reservation)
            objectUploaded = true
        }
        let result = try await client.completeUpload(reservation)
        try Task.checkCancellation()
        guard revision == client.sessionRevision else { throw CancellationError() }
        completedResponse = result
        self.data = nil
        return result
    }
}

/// The preview owner retains this artifact and removes it when dismissed.
/// Session changes also delete it, so former-account files never become a cache.
final class ServerDownloadedUpload: @unchecked Sendable {
    private let directoryURL: URL
    private let fileURL: URL
    private let revision: UUID
    private weak var client: ServerClient?
    private let lock = NSLock()
    private var removed = false
    private var observer: NSObjectProtocol?

    var localURL: URL? {
        lock.withLock {
            guard !removed, client?.sessionRevision == revision else { return nil }
            return fileURL
        }
    }

    init(directoryURL: URL, fileURL: URL, client: ServerClient, revision: UUID) {
        self.directoryURL = directoryURL
        self.fileURL = fileURL
        self.client = client
        self.revision = revision
        observer = NotificationCenter.default.addObserver(
            forName: .serverSessionDidChange, object: nil, queue: nil
        ) { [weak self, weak client] notification in
            guard let client, let changed = notification.object as? ServerClient,
                  changed === client else { return }
            self?.remove()
        }
    }

    func remove() {
        let shouldRemove = lock.withLock {
            guard !removed else { return false }
            removed = true
            return true
        }
        if shouldRemove { try? FileManager.default.removeItem(at: directoryURL) }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        remove()
    }
}

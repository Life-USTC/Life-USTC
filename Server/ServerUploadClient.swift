import Foundation

extension ServerClient {
    func fetchUploadsPage(page: Int = 1, pageSize: Int = 100) async throws -> ServerUploadListResponse {
        try await fetchUploadsPage(page: page, pageSize: pageSize, revision: sessionRevision)
    }

    func fetchAllUploads() async throws -> ServerUploadCollection {
        let revision = sessionRevision
        let first = try await fetchUploadsPage(page: 1, pageSize: 100, revision: revision)
        var uploads = first.data
        var page = 1
        var totalPages = first.pagination.totalPages
        while page < totalPages {
            page += 1
            let response = try await fetchUploadsPage(page: page, pageSize: 100, revision: revision)
            uploads.append(contentsOf: response.data)
            totalPages = response.pagination.totalPages
        }
        try checkUploadSession(revision)
        return ServerUploadCollection(uploads: uploads, quota: first.meta)
    }

    func reserveUpload(
        filename: String, contentType: String? = nil, size: Int, expectedRevision: UUID? = nil
    ) async throws -> ServerUploadReservation {
        let context = authorizationContext
        if let expectedRevision, expectedRevision != context.revision { throw CancellationError() }
        try checkUploadSession(context.revision)
        let filename = try uploadFilename(filename)
        let contentType = try uploadContentType(contentType)
        guard size > 0 else { throw ServerError.badRequest("File must not be empty") }
        let response: CreateUploadResponse = try await request(
            .createUpload(CreateUploadRequest(filename: filename, contentType: contentType, size: size)),
            retry: true, expectedRevision: context.revision
        )
        try checkUploadSession(context.revision)
        guard let objectURL = URL(string: response.url, relativeTo: context.baseURL)?.absoluteURL,
              objectURL.path == "/api/workspace/uploads/object",
              objectURL.fragment == nil,
              let components = URLComponents(url: objectURL, resolvingAgainstBaseURL: false),
              components.queryItems?.count == 1,
              components.queryItems?.first?.name == "key",
              components.queryItems?.first?.value == response.key,
              !response.key.isEmpty,
              response.maxFileSizeBytes >= size,
              response.quotaBytes >= 0, response.usedBytes >= 0 else {
            throw ServerError.serverError("Invalid upload reservation")
        }
        return ServerUploadReservation(
            filename: filename, contentType: contentType, size: size,
            quota: ServerUploadQuota(maxFileSizeBytes: response.maxFileSizeBytes,
                                     quotaBytes: response.quotaBytes, usedBytes: response.usedBytes),
            key: response.key, objectURL: objectURL, revision: context.revision
        )
    }

    func putUpload(data: Data, reservation: ServerUploadReservation) async throws {
        try checkUploadSession(reservation.revision)
        guard data.count == reservation.size else {
            throw ServerError.badRequest("File size changed after upload reservation")
        }
        var request = URLRequest(url: reservation.objectURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(reservation.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        let responseData = try await requestBinary(request, expectedRevision: reservation.revision)
        let result: SuccessResponse
        do { result = try decoder.decode(SuccessResponse.self, from: responseData) }
        catch { throw ServerError.decodingError(error) }
        guard result.success else { throw ServerError.serverError("Upload did not complete") }
        try checkUploadSession(reservation.revision)
    }

    func completeUpload(_ reservation: ServerUploadReservation) async throws -> ServerUploadCompletionResponse {
        try checkUploadSession(reservation.revision)
        let response: ServerUploadCompletionResponse = try await request(
            .completeUpload(CompleteUploadRequest(key: reservation.key, filename: reservation.filename,
                                                 contentType: reservation.contentType)),
            retry: true, expectedRevision: reservation.revision
        )
        try checkUploadSession(reservation.revision)
        guard !response.upload.id.isEmpty, response.upload.key == reservation.key else {
            throw ServerError.serverError("Invalid completed upload")
        }
        return response
    }

    func renameUpload(id: String, filename: String, expectedRevision: UUID? = nil) async throws -> ServerUpload {
        let revision = expectedRevision ?? sessionRevision
        try checkUploadSession(revision)
        let filename = try uploadFilename(filename, maximumLength: 255)
        let response: ServerUploadRenameResponse = try await request(
            .renameUpload(id: id, request: RenameUploadRequest(filename: filename)),
            retry: true, expectedRevision: revision
        )
        try checkUploadSession(revision)
        guard response.upload.id == id else { throw ServerError.serverError("Invalid renamed upload") }
        return response.upload
    }

    @discardableResult
    func deleteUpload(id: String, expectedRevision: UUID? = nil) async throws -> ServerUploadDeleteResponse {
        let revision = expectedRevision ?? sessionRevision
        try checkUploadSession(revision)
        let response: ServerUploadDeleteResponse = try await request(
            .deleteUpload(id: id), retry: true, expectedRevision: revision
        )
        try checkUploadSession(revision)
        guard response.deletedId == id else { throw ServerError.serverError("Invalid deleted upload") }
        return response
    }

    func downloadUpload(id: String, filename: String, expectedRevision: UUID? = nil) async throws -> ServerDownloadedUpload {
        let context = authorizationContext
        if let expectedRevision, expectedRevision != context.revision { throw CancellationError() }
        try checkUploadSession(context.revision)
        let request = ServerEndpoint.downloadUpload(id: id).buildURLRequest(baseURL: context.baseURL)
        let data = try await requestBinary(request, expectedRevision: context.revision)
        try checkUploadSession(context.revision)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeUSTC-upload-\(UUID().uuidString)", isDirectory: true)
        let basename = (filename.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
        let safeName = ["", ".", ".."].contains(basename) ? "attachment" : basename
        let file = directory.appendingPathComponent(safeName, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
            let artifact = ServerDownloadedUpload(directoryURL: directory, fileURL: file,
                                                  client: self, revision: context.revision)
            try checkUploadSession(context.revision)
            return artifact
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private func fetchUploadsPage(page: Int, pageSize: Int, revision: UUID) async throws -> ServerUploadListResponse {
        try checkUploadSession(revision)
        guard page > 0, (1...100).contains(pageSize) else {
            throw ServerError.badRequest("Invalid upload pagination")
        }
        let response: ServerUploadListResponse = try await request(
            .listUploads(page: page, pageSize: pageSize), retry: true, expectedRevision: revision
        )
        try checkUploadSession(revision)
        guard response.pagination.page == page, response.pagination.pageSize == pageSize,
              response.pagination.totalPages >= 0, response.pagination.total >= 0,
              response.data.count <= pageSize else {
            throw ServerError.serverError("Invalid upload pagination response")
        }
        return response
    }

    private func checkUploadSession(_ revision: UUID) throws {
        try Task.checkCancellation()
        guard revision == sessionRevision else { throw CancellationError() }
        guard isAuthenticated else { throw ServerError.notAuthenticated }
    }

    private func uploadFilename(_ value: String, maximumLength: Int? = nil) throws -> String {
        guard !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else {
            throw ServerError.badRequest("Filename contains unsupported control characters")
        }
        let filename = trimUploadText(value)
        guard !filename.isEmpty else { throw ServerError.badRequest("Filename required") }
        if let maximumLength, filename.utf16.count > maximumLength {
            throw ServerError.badRequest("Filename must be at most 255 characters")
        }
        return filename
    }

    private func uploadContentType(_ value: String?) throws -> String {
        let type = value.map(trimUploadText) ?? ""
        guard !type.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else {
            throw ServerError.badRequest("Invalid file content type")
        }
        return type.isEmpty ? "application/octet-stream" : type
    }

    private func trimUploadText(_ value: String) -> String {
        let whitespace = CharacterSet(charactersIn:
            "\u{0009}\u{000a}\u{000b}\u{000c}\u{000d}\u{0020}\u{00a0}\u{1680}" +
            "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}" +
            "\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}")
        return value.trimmingCharacters(in: whitespace)
    }
}

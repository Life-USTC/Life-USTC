import XCTest
@testable import Life_USTC

final class OwnedFilesModelTests: XCTestCase {
    private var client: ServerClient!
    private let bytes = Data([0, 1, 2, 255])

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "file-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://files.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testAnonymousFilesRemainEmptyWithoutMakingPrivateRequests() async {
        client.clearTokens()
        let model = ServerOwnedFilesModel(client: client)
        await model.load()
        await model.refreshQuota()
        let renamed = await model.rename(id: "file", filename: "new.pdf")
        let deleted = await model.delete(id: "file")
        let downloaded = await model.download(id: "file")
        XCTAssertFalse(renamed)
        XCTAssertFalse(deleted)
        XCTAssertFalse(downloaded)
        XCTAssertTrue(model.uploads.isEmpty)
        XCTAssertNil(model.quota)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testFailedRefreshRetainsSameOwnerFilesAndQuotaUntilSuccessfulRetry() async {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubJSON(["error": "Files unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.uploads.map(\.id), ["file", "other"])
        XCTAssertEqual(model.quota?.usedBytes, 400)
        XCTAssertEqual(model.quota?.quotaBytes, 4096)
        XCTAssertEqual(model.quota?.maxFileSizeBytes, 1024)
        XCTAssertNotNil(model.loadError)
        XCTAssertFalse(model.isLoading)
        MockURLProtocol.stubJSON(collection(ids: ["current"], usedBytes: 300))
        await model.load()
        XCTAssertEqual(model.uploads.map(\.id), ["current"])
        XCTAssertEqual(model.quota?.usedBytes, 300)
        XCTAssertNil(model.loadError)
    }

    @MainActor
    func testFailedRenamePreservesCanonicalRowAndRetriesSameIdentityAndFilename() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubJSON(["error": "Rename unavailable"], statusCode: 503)
        let failed = await model.rename(id: "file", filename: "  Edited notes.pdf  ")
        XCTAssertFalse(failed)
        XCTAssertEqual(model.uploads.first?.filename, "file.bin")
        XCTAssertEqual(model.quota?.usedBytes, 400)
        XCTAssertNotNil(model.mutationError)
        XCTAssertNil(model.mutatingID)
        XCTAssertTrue(model.canRetryMutation)
        MockURLProtocol.stubJSON(["upload": upload(id: "file", filename: "Canonical notes.pdf")])
        let saved = await model.retryMutation()
        XCTAssertTrue(saved)
        XCTAssertEqual(model.uploads.map(\.filename), ["Canonical notes.pdf", "other.bin"])
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.canRetryMutation)
        let writes = MockURLProtocol.capturedRequests.filter { $0.httpMethod == "PATCH" }
        XCTAssertEqual(writes.count, 2)
        for request in writes {
            XCTAssertEqual(request.url?.path, "/api/workspace/uploads/file")
            XCTAssertEqual(try body(request)["filename"] as? String, "Edited notes.pdf")
        }
    }

    @MainActor
    func testRenameKeepsCurrentRowWhileAwaitingServerAndRejectsDuplicateWrite() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        let started = expectation(description: "Rename reached the server")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let data = try JSONSerialization.data(withJSONObject: ["upload": upload(id: "file", filename: "confirmed.pdf")])
        MockURLProtocol.requestHandler = { request in
            started.fulfill()
            guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let writing = Task { await model.rename(id: "file", filename: "confirmed.pdf") }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(model.mutatingID, "file")
        XCTAssertEqual(model.uploads.first?.filename, "file.bin")
        let duplicate = await model.delete(id: "file")
        XCTAssertFalse(duplicate)
        release.signal()
        let saved = await writing.value
        XCTAssertTrue(saved)
        XCTAssertEqual(model.uploads.first?.filename, "confirmed.pdf")
        XCTAssertNil(model.mutatingID)
    }

    @MainActor
    func testStorageDeleteFailureKeepsRowAndExplicitRetryReadsCanonicalQuota() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubJSON(["error": "Failed to delete upload object"], statusCode: 502)
        let failed = await model.delete(id: "file")
        XCTAssertFalse(failed)
        XCTAssertEqual(model.uploads.map(\.id), ["file", "other"])
        XCTAssertEqual(model.quota?.usedBytes, 400)
        XCTAssertNotNil(model.mutationError)
        XCTAssertTrue(model.canRetryMutation)

        let quota = collection(ids: ["other"], pageSize: 1, usedBytes: 350)
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "DELETE" {
                return try self.response(request, ["deletedId": "file", "deletedSize": 4])
            }
            XCTAssertEqual(self.query(request), ["page": "1", "pageSize": "1"])
            return try self.response(request, quota)
        }
        let deleted = await model.retryMutation()
        XCTAssertTrue(deleted)
        XCTAssertEqual(model.uploads.map(\.id), ["other"])
        XCTAssertEqual(model.quota?.usedBytes, 350, "Quota is reread, not guessed by subtracting deletedSize")
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.canRetryMutation)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "DELETE" }.count, 2)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "GET")
    }

    @MainActor
    func testCommittedDeleteKeepsRowRemovedAndQuotaUnknownWhenQuotaReadFails() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "DELETE"
                ? try self.response(request, ["deletedId": "file", "deletedSize": 4])
                : try self.response(request, ["error": "Quota unavailable"], status: 503)
        }
        let deleted = await model.delete(id: "file")
        XCTAssertTrue(deleted, "A later quota failure does not undo a confirmed deletion")
        XCTAssertEqual(model.uploads.map(\.id), ["other"])
        XCTAssertNil(model.quota)
        XCTAssertNotNil(model.quotaError)
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.canRetryMutation)
        XCTAssertFalse(model.isRefreshingQuota)

        MockURLProtocol.stubJSON(["error": "Still unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.uploads.map(\.id), ["other"])
        XCTAssertNil(model.quota)
        MockURLProtocol.stubJSON(collection(ids: ["other"], pageSize: 1, usedBytes: 100))
        await model.refreshQuota()
        XCTAssertEqual(model.quota?.usedBytes, 100)
        XCTAssertNil(model.quotaError)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "DELETE" }.count, 1)
    }

    @MainActor
    func testReplacementAccountImmediatelyHidesFilesQuotaErrorsAndRetryIntent() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        _ = await model.rename(id: "file", filename: "Previous owner.pdf")
        _ = await model.download(id: "file")
        XCTAssertNotNil(model.loadError)
        XCTAssertNotNil(model.mutationError)
        XCTAssertNotNil(model.downloadError)
        XCTAssertTrue(model.canRetryMutation)
        try replaceAccount()
        XCTAssertTrue(model.uploads.isEmpty)
        XCTAssertNil(model.quota)
        XCTAssertNil(model.loadError)
        XCTAssertNil(model.mutationError)
        XCTAssertNil(model.downloadError)
        XCTAssertNil(model.mutatingID)
        XCTAssertNil(model.downloadingID)
        XCTAssertFalse(model.canRetryMutation)
        let before = MockURLProtocol.capturedRequests.count
        let retried = await model.retryMutation()
        let renamed = await model.rename(id: "file", filename: "Must not transfer.pdf")
        XCTAssertFalse(retried)
        XCTAssertFalse(renamed)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        MockURLProtocol.stubJSON(collection(ids: ["current-owner-file"], usedBytes: 25))
        await model.load()
        XCTAssertEqual(model.uploads.map(\.id), ["current-owner-file"])
        XCTAssertEqual(model.quota?.usedBytes, 25)
        XCTAssertFalse(model.canRetryMutation)
    }

    @MainActor
    func testLateRenameAndDeleteResponsesCannotPublishSuccessAfterAccountReplacement() async throws {
        for operation in ["rename", "delete"] {
            let model = ServerOwnedFilesModel(client: client)
            MockURLProtocol.stubJSON(collection())
            await model.load()
            let client = client!
            let responseBody: [String: Any] = operation == "rename"
                ? ["upload": upload(id: "file", filename: "Former owner.pdf")]
                : ["deletedId": "file", "deletedSize": 4]
            let data = try JSONSerialization.data(withJSONObject: responseBody)
            MockURLProtocol.requestHandler = { request in
                try client.acceptAuthorization(OAuthTokenResponse(
                    accessToken: "replacement", tokenType: "Bearer", expiresIn: nil,
                    refreshToken: nil, scope: nil
                ), expectedRevision: client.sessionRevision)
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }
            let before = MockURLProtocol.capturedRequests.count
            let saved = operation == "rename"
                ? await model.rename(id: "file", filename: "Former owner.pdf")
                : await model.delete(id: "file")
            XCTAssertFalse(saved)
            XCTAssertTrue(model.uploads.isEmpty)
            XCTAssertNil(model.quota)
            XCTAssertNil(model.mutationError)
            XCTAssertFalse(model.canRetryMutation)
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, before + 1)
        }
    }

    @MainActor
    func testPreviewReplacementDismissalAndSessionChangeRemoveTemporaryFiles() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubData(bytes)
        let firstDownloaded = await model.download(id: "file")
        XCTAssertTrue(firstDownloaded)
        let first = try XCTUnwrap(model.preview)
        let firstURL = try XCTUnwrap(first.localURL)
        XCTAssertEqual(try Data(contentsOf: firstURL), bytes)
        XCTAssertNil(model.downloadingID)
        let nextDownloaded = await model.download(id: "other")
        XCTAssertTrue(nextDownloaded)
        XCTAssertNil(first.localURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        let secondURL = try XCTUnwrap(model.preview?.localURL)
        XCTAssertEqual(secondURL.lastPathComponent, "other.bin")
        model.dismissPreview()
        XCTAssertNil(model.preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path))

        _ = await model.download(id: "file")
        let thirdURL = try XCTUnwrap(model.preview?.localURL)
        try replaceAccount()
        XCTAssertNil(model.preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: thirdURL.path))
    }

    @MainActor
    func testFailedPreviewPreservesFilesAndExplicitDownloadRetryCanSucceed() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubJSON(["error": "Download unavailable"], statusCode: 503)
        let failed = await model.download(id: "file")
        XCTAssertFalse(failed)
        XCTAssertNil(model.preview)
        XCTAssertNil(model.downloadingID)
        XCTAssertNotNil(model.downloadError)
        XCTAssertEqual(model.uploads.map(\.id), ["file", "other"])
        XCTAssertEqual(model.quota?.usedBytes, 400)
        MockURLProtocol.stubData(bytes)
        let downloaded = await model.download(id: "file")
        XCTAssertTrue(downloaded)
        XCTAssertNotNil(model.preview?.localURL)
        XCTAssertNil(model.downloadError)
        model.dismissPreview()
    }

    @MainActor
    func testDismissingPendingDownloadPreventsLatePreviewAndError() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        let started = expectation(description: "Download reached the server")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let data = bytes
        MockURLProtocol.requestHandler = { request in
            started.fulfill()
            guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let downloading = Task { await model.download(id: "file") }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(model.downloadingID, "file")
        model.dismissPreview()
        XCTAssertNil(model.downloadingID)
        release.signal()
        let downloaded = await downloading.value
        XCTAssertFalse(downloaded)
        XCTAssertNil(model.preview)
        XCTAssertNil(model.downloadError)
    }

    @MainActor
    func testDeleteOnlyClosesPreviewAfterServerConfirmsDeletion() async throws {
        let model = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model.load()
        MockURLProtocol.stubData(bytes)
        _ = await model.download(id: "file")
        let file = try XCTUnwrap(model.preview?.localURL)
        MockURLProtocol.stubJSON(["error": "Failed to delete upload object"], statusCode: 502)
        _ = await model.delete(id: "file")
        XCTAssertNotNil(model.preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "DELETE"
                ? try self.response(request, ["deletedId": "file", "deletedSize": 4])
                : try self.response(request, self.collection(ids: ["other"], pageSize: 1, usedBytes: 100))
        }
        let deleted = await model.retryMutation()
        XCTAssertTrue(deleted)
        XCTAssertNil(model.preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testReleasingModelRemovesPreviewFile() async throws {
        var model: ServerOwnedFilesModel? = ServerOwnedFilesModel(client: client)
        MockURLProtocol.stubJSON(collection())
        await model?.load()
        MockURLProtocol.stubData(bytes)
        _ = await model?.download(id: "file")
        weak var artifact = model?.preview
        let file = try XCTUnwrap(artifact?.localURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        model = nil
        XCTAssertNil(artifact)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testStaleRevisionCannotRenameDeleteOrDownloadUnderReplacementAccount() async throws {
        let revision = client.sessionRevision
        try replaceAccount()
        do {
            _ = try await client.renameUpload(id: "file", filename: "Old draft.pdf", expectedRevision: revision)
            XCTFail("A stale rename must be rejected before a request")
        } catch is CancellationError { }
        do {
            _ = try await client.deleteUpload(id: "file", expectedRevision: revision)
            XCTFail("A stale delete must be rejected before a request")
        } catch is CancellationError { }
        do {
            _ = try await client.downloadUpload(id: "file", filename: "Old draft.pdf", expectedRevision: revision)
            XCTFail("A stale preview must be rejected before a request")
        } catch is CancellationError { }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        XCTAssertEqual(client.accessToken, "replacement")
    }

    private func replaceAccount() throws {
        try client.acceptAuthorization(OAuthTokenResponse(
            accessToken: "replacement", tokenType: "Bearer", expiresIn: nil,
            refreshToken: nil, scope: nil
        ), expectedRevision: client.sessionRevision)
    }

    private func upload(id: String, filename: String? = nil) -> [String: Any] {
        ["id": id, "key": "uploads/owner/\(id)", "filename": filename ?? "\(id).bin",
         "size": 4, "createdAt": "2026-10-23T02:03:04Z"]
    }

    private func collection(ids: [String] = ["file", "other"], pageSize: Int = 100,
                            usedBytes: Int = 400) -> [String: Any] {
        ["data": ids.map { upload(id: $0) },
         "pagination": ["page": 1, "pageSize": pageSize, "total": ids.count, "totalPages": ids.isEmpty ? 0 : 1],
         "meta": ["maxFileSizeBytes": 1024, "quotaBytes": 4096, "usedBytes": usedBytes]]
    }

    private func response(_ request: URLRequest, _ json: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                         headerFields: ["Content-Type": "application/json"])!,
         try JSONSerialization.data(withJSONObject: json))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

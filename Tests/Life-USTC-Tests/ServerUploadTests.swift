import XCTest
@testable import Life_USTC

final class ServerUploadTests: XCTestCase {
    private var client: ServerClient!
    private var tokens: MockTokenStore!
    private let key = "uploads/fixture-owner/reserved-key"
    private let bytes = Data([0, 1, 2, 255])

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        tokens = MockTokenStore()
        tokens.accessToken = "upload-owner"
        client = ServerClient(configuration: ServerClientConfiguration(
            baseURL: URL(string: "https://uploads.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: "serverBaseURL")
        client = nil
        tokens = nil
        super.tearDown()
    }

    func testOwnedFilesExhaustPagesAndKeepQuota() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = self.query(request)
            let page = Int(query["page"] ?? "0")!
            XCTAssertEqual(request.url?.path, "/api/workspace/uploads")
            XCTAssertEqual(query["pageSize"], "100")
            XCTAssertNil(query["limit"])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer upload-owner")
            return try self.response(request, [
                "data": ((page - 1) * 100..<min(page * 100, 101)).map { self.upload(id: "file-\($0)") },
                "pagination": ["page": page, "pageSize": 100, "total": 101, "totalPages": 2],
                "meta": self.quota,
            ])
        }
        let result = try await client.fetchAllUploads()
        XCTAssertEqual(result.uploads.map(\.id), (0..<101).map { "file-\($0)" })
        XCTAssertEqual(result.quota.usedBytes, 400)
        XCTAssertEqual(result.quota.quotaBytes, 4096)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testInvalidPaginationAndFailedLaterPageDoNotReturnPartialFiles() async throws {
        for failure in ["wrong-page", "offline"] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                let page = Int(self.query(request)["page"] ?? "0")!
                if page == 2, failure == "offline" {
                    return try self.response(request, ["error": "Files unavailable"], status: 503)
                }
                return try self.response(request, [
                    "data": [self.upload()],
                    "pagination": ["page": 1, "pageSize": 100, "total": 101, "totalPages": 2],
                    "meta": self.quota,
                ])
            }
            do {
                _ = try await client.fetchAllUploads()
                XCTFail("A failed later page must not look like a complete file list")
            } catch ServerError.serverError { }
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        }
    }

    func testOwnedFilePageRejectsInvalidPageSizeBeforeNetwork() async throws {
        do {
            _ = try await client.fetchUploadsPage(pageSize: 101)
            XCTFail("Upload pagination is bounded to 100")
        } catch ServerError.badRequest { }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    func testLogoutDuringPaginationDiscardsTheEntireFileList() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            let page = Int(self.query(request)["page"] ?? "0")!
            if page == 2 { client.clearTokens() }
            return try self.response(request, [
                "data": [self.upload(id: "file-\(page)")],
                "pagination": ["page": page, "pageSize": 100, "total": 101, "totalPages": 2],
                "meta": self.quota,
            ])
        }
        do {
            _ = try await client.fetchAllUploads()
            XCTFail("Private upload pages must never span two sessions")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    @MainActor
    func testDraftUploadsRawBytesThenUsesCompletedServerID() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer upload-owner")
            switch request.url?.path {
            case "/api/workspace/uploads":
                XCTAssertEqual(request.httpMethod, "POST")
                let body = try self.jsonBody(request)
                XCTAssertEqual(Set(body.keys), ["filename", "contentType", "size"])
                XCTAssertEqual(body["filename"] as? String, "notes.bin")
                XCTAssertEqual(body["contentType"] as? String, "application/octet-stream")
                XCTAssertEqual(body["size"] as? Int, 4)
                return try self.response(request, self.reservation())
            case "/api/workspace/uploads/object":
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Length"), "4")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
                XCTAssertEqual(self.query(request)["key"], self.key)
                XCTAssertEqual(try self.bodyData(request), self.bytes)
                XCTAssertFalse(request.httpShouldHandleCookies)
                XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
                return try self.response(request, ["success": true])
            case "/api/workspace/uploads/complete":
                XCTAssertEqual(request.httpMethod, "POST")
                let body = try self.jsonBody(request)
                XCTAssertEqual(Set(body.keys), ["key", "filename", "contentType"])
                XCTAssertEqual(body["key"] as? String, self.key)
                XCTAssertEqual(body["filename"] as? String, "notes.bin")
                return try self.response(request, self.completion(id: "actual-server-upload-id"))
            default:
                XCTFail("Unexpected upload route")
                return try self.response(request, [:], status: 404)
            }
        }
        let draft = ServerUploadDraft(data: bytes, filename: " notes.bin ")
        let result = try await draft.upload(using: client)
        XCTAssertEqual(result.upload.id, "actual-server-upload-id")
        XCTAssertEqual(result.upload.key, key)
        XCTAssertEqual(result.usedBytes, 404)
        XCTAssertEqual(draft.completion?.upload.id, result.upload.id)
        XCTAssertFalse(draft.isUploading)
        _ = try await draft.upload(using: client)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3, "An already completed draft is not uploaded again")
        client.clearTokens()
        XCTAssertNil(draft.completion, "Completed attachment state belongs to the original session")
    }

    @MainActor
    func testRetryResumesOnlyUnfinishedPhase() async throws {
        for failedPath in ["/api/workspace/uploads/object", "/api/workspace/uploads/complete"] {
            MockURLProtocol.reset()
            var failed = false
            MockURLProtocol.requestHandler = { request in
                if request.url?.path == failedPath, !failed {
                    failed = true
                    return try self.response(request, ["error": "Try again"], status: 503)
                }
                return try self.uploadResponse(request)
            }
            let draft = ServerUploadDraft(data: bytes, filename: "notes.bin", contentType: "application/pdf")
            do {
                _ = try await draft.upload(using: client)
                XCTFail("The failed phase must remain retryable")
            } catch ServerError.serverError { }
            XCTAssertNil(draft.completion)
            XCTAssertFalse(draft.isUploading)
            let completed = try await draft.upload(using: client)
            XCTAssertEqual(completed.upload.id, "server-file")
            let paths = MockURLProtocol.capturedRequests.compactMap { $0.url?.path }
            XCTAssertEqual(paths.filter { $0 == "/api/workspace/uploads" }.count, 1)
            XCTAssertEqual(paths.filter { $0 == "/api/workspace/uploads/object" }.count,
                           failedPath.hasSuffix("object") ? 2 : 1)
            XCTAssertEqual(paths.filter { $0 == "/api/workspace/uploads/complete" }.count,
                           failedPath.hasSuffix("complete") ? 2 : 1)
        }
    }

    func testRawPutCannotUseDifferentSizeThanReserved() async throws {
        MockURLProtocol.stubJSON(reservation())
        let pending = try await client.reserveUpload(filename: "notes.bin", size: bytes.count)
        do {
            try await client.putUpload(data: bytes + Data([3]), reservation: pending)
            XCTFail("A reservation must not send changed file bytes")
        } catch ServerError.badRequest { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    @MainActor
    func testForeignUploadURLNeverReceivesFileOrBearer() async throws {
        for origin in ["https://other.example", "http://uploads.example", "https://uploads.example:444", "https://user@uploads.example"] {
            MockURLProtocol.reset()
            MockURLProtocol.stubJSON(reservation(origin: origin))
            let draft = ServerUploadDraft(data: bytes, filename: "notes.bin")
            do {
                _ = try await draft.upload(using: client)
                XCTFail("Server-returned upload URLs must stay on the authorized origin")
            } catch ServerError.badRequest { }
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
            XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.host, "uploads.example")
        }
    }

    func testReservationRejectsWrongObjectRouteOrKey() async throws {
        for url in ["https://uploads.example/not-the-object-route?key=wrong", "https://uploads.example/api/workspace/uploads/object?key=wrong"] {
            var payload = reservation()
            payload["url"] = url
            MockURLProtocol.stubJSON(payload)
            do {
                _ = try await client.reserveUpload(filename: "notes.bin", size: bytes.count)
                XCTFail("The object URL must address the exact reserved key")
            } catch ServerError.serverError { }
        }
    }

    @MainActor
    func testSessionChangeAtAnyUploadPhaseStopsTheDraft() async throws {
        for changedPath in ["/api/workspace/uploads", "/api/workspace/uploads/object", "/api/workspace/uploads/complete"] {
            MockURLProtocol.reset()
            tokens.accessToken = "upload-owner"
            let client = self.client!
            MockURLProtocol.requestHandler = { request in
                let response = try self.uploadResponse(request)
                if request.url?.path == changedPath { client.clearTokens() }
                return response
            }
            let draft = ServerUploadDraft(data: bytes, filename: "notes.bin")
            do {
                _ = try await draft.upload(using: client)
                XCTFail("An upload response must not transfer into another session")
            } catch is CancellationError { }
            XCTAssertNil(draft.completion)
            let count = MockURLProtocol.capturedRequests.count
            tokens.accessToken = "new-owner"
            do {
                _ = try await draft.upload(using: client)
                XCTFail("Retry must not reuse a former owner's draft")
            } catch is CancellationError { }
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, count)
        }
    }

    func testFormerReservationCannotBePutOrCompletedAfterBackendChange() async throws {
        MockURLProtocol.stubJSON(reservation())
        let pending = try await client.reserveUpload(filename: "notes.bin", size: bytes.count)
        client.reconfigure(baseURL: URL(string: "https://new.example")!)
        tokens.accessToken = "new-owner"
        do {
            try await client.putUpload(data: bytes, reservation: pending)
            XCTFail("Old bytes must never reach a new backend")
        } catch is CancellationError { }
        do {
            _ = try await client.completeUpload(pending)
            XCTFail("Old reservation keys must never reach a new backend")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    func testDownloadUsesAuthenticatedBytesAndSafeDisposableLocalArtifact() async throws {
        MockURLProtocol.stubData(bytes, contentType: "application/octet-stream")
        let artifact = try await client.downloadUpload(id: "server-file", filename: "../../notes.bin")
        let file = try XCTUnwrap(artifact.localURL)
        XCTAssertEqual(file.lastPathComponent, "notes.bin")
        XCTAssertTrue(file.deletingLastPathComponent().lastPathComponent.hasPrefix("LifeUSTC-upload-"))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/workspace/uploads/server-file/download")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer upload-owner")
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        artifact.remove()
        XCTAssertNil(artifact.localURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDownloadedFileIsRemovedWhenSessionChangesOrArtifactIsReleased() async throws {
        MockURLProtocol.stubData(bytes)
        let artifact = try await client.downloadUpload(id: "server-file", filename: "notes.bin")
        let file = try XCTUnwrap(artifact.localURL)
        client.clearTokens()
        XCTAssertNil(artifact.localURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        tokens.accessToken = "new-owner"
        var second: ServerDownloadedUpload? = try await client.downloadUpload(id: "second-file", filename: "notes.bin")
        let secondFile = try XCTUnwrap(second?.localURL)
        second = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondFile.path))
    }

    func testDownloadAfterLogoutDiscardsBytesBeforeCreatingArtifact() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.bytes)
        }
        do {
            _ = try await client.downloadUpload(id: "server-file", filename: "notes.bin")
            XCTFail("A former owner's response must not create an artifact")
        } catch is CancellationError { }
    }

    func testDownload401RefreshesOnceWithoutChangingAuthority() async throws {
        tokens.refreshToken = "upload-refresh"
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/auth/oauth2/token" {
                return try self.response(request, ["access_token": "renewed-owner", "token_type": "Bearer"])
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer upload-owner" {
                return try self.response(request, ["error": "expired"], status: 401)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer renewed-owner")
            XCTAssertEqual(request.url?.host, "uploads.example")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.bytes)
        }
        let artifact = try await client.downloadUpload(id: "server-file", filename: "notes.bin")
        defer { artifact.remove() }
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(artifact.localURL)), bytes)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)
    }

    func testMissingScopeDoesNotAttemptRefreshOrCreateArtifact() async throws {
        tokens.refreshToken = "upload-refresh"
        MockURLProtocol.stubJSON(["error": "insufficient_scope", "scope": "workspace.upload:read"], statusCode: 403)
        do {
            _ = try await client.downloadUpload(id: "server-file", filename: "notes.bin")
            XCTFail("Missing upload scope must remain forbidden")
        } catch ServerError.forbidden { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertEqual(tokens.accessToken, "upload-owner")
    }

    func testDownloadRefreshCannotTransferCredentialsToNewBackend() async throws {
        let client = self.client!
        tokens.refreshToken = "upload-refresh"
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/auth/oauth2/token" {
                client.reconfigure(baseURL: URL(string: "https://new.example")!)
                return try self.response(request, ["access_token": "former-owner-renewed", "token_type": "Bearer"])
            }
            return try self.response(request, ["error": "expired"], status: 401)
        }
        do {
            _ = try await client.downloadUpload(id: "server-file", filename: "notes.bin")
            XCTFail("Refresh must not revive a former backend's attachment request")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        XCTAssertTrue(MockURLProtocol.capturedRequests.allSatisfy { $0.url?.host == "uploads.example" })
        XCTAssertTrue(tokens.accessToken.isEmpty)
    }

    func testRenameAndDeleteUseServerIdentityAndRetainFailedDeleteForRetry() async throws {
        MockURLProtocol.stubJSON(["upload": upload(filename: "renamed.pdf")])
        let renamed = try await client.renameUpload(id: "server-file", filename: " renamed.pdf ")
        XCTAssertEqual(renamed.filename, "renamed.pdf")
        let rename = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(rename.httpMethod, "PATCH")
        XCTAssertEqual(rename.url?.path, "/api/workspace/uploads/server-file")
        XCTAssertEqual(try jsonBody(rename)["filename"] as? String, "renamed.pdf")

        MockURLProtocol.stubJSON(["error": "Failed to delete upload object"], statusCode: 502)
        do {
            _ = try await client.deleteUpload(id: renamed.id)
            XCTFail("A storage failure must not report a completed deletion")
        } catch ServerError.serverError { }
        MockURLProtocol.stubJSON(["deletedId": renamed.id, "deletedSize": 4])
        let deleted = try await client.deleteUpload(id: renamed.id)
        XCTAssertEqual(deleted.deletedId, renamed.id)
        XCTAssertEqual(deleted.deletedSize, 4)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.path, "/api/workspace/uploads/server-file")
    }

    func testFilenameValidationMatchesUTF16LimitAndRejectsControls() async throws {
        for filename in ["line\nfeed.pdf", String(repeating: "😀", count: 128), "\u{feff}"] {
            do {
                _ = try await client.renameUpload(id: "server-file", filename: filename)
                XCTFail("Invalid filename must be rejected before a request")
            } catch ServerError.badRequest { }
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        MockURLProtocol.stubJSON(["upload": upload(filename: "name.pdf")])
        _ = try await client.renameUpload(id: "server-file", filename: "\u{feff}name.pdf\u{feff}")
        XCTAssertEqual(try jsonBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))["filename"] as? String, "name.pdf")
    }

    private var quota: [String: Int] { ["maxFileSizeBytes": 1024, "quotaBytes": 4096, "usedBytes": 400] }

    private func reservation(origin: String = "https://uploads.example") -> [String: Any] {
        var url = URLComponents(string: origin + "/api/workspace/uploads/object")!
        url.queryItems = [URLQueryItem(name: "key", value: key)]
        return ["key": key, "url": url.url!.absoluteString,
                "maxFileSizeBytes": 1024, "quotaBytes": 4096, "usedBytes": 400]
    }

    private func upload(id: String = "server-file", filename: String = "notes.bin") -> [String: Any] {
        ["id": id, "key": key, "filename": filename, "size": 4, "createdAt": "2026-10-23T02:03:04Z"]
    }

    private func completion(id: String = "server-file") -> [String: Any] {
        ["upload": upload(id: id), "usedBytes": 404, "quotaBytes": 4096]
    }

    private func uploadResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        switch request.url?.path {
        case "/api/workspace/uploads": return try response(request, reservation())
        case "/api/workspace/uploads/object": return try response(request, ["success": true])
        case "/api/workspace/uploads/complete": return try response(request, completion())
        default: return try response(request, [:], status: 404)
        }
    }

    private func response(_ request: URLRequest, _ body: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                         headerFields: ["Content-Type": "application/json"])!,
         try JSONSerialization.data(withJSONObject: body))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData(request)) as? [String: Any])
    }

    private func bodyData(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

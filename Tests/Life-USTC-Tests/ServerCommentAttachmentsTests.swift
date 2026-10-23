import XCTest
@testable import Life_USTC

final class ServerCommentAttachmentsTests: XCTestCase {
    private var client: ServerClient!
    private let bytes = Data([0, 1, 2, 255])
    private let key = "uploads/owner/reservation"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "attachment-owner"
        client = ServerClient(configuration: .init(baseURL: URL(string: "https://attachments.example")!,
                                                  session: MockURLProtocol.mockSession(), tokenStore: tokens))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testEditingPreservesUploadIDsAndRemovalDoesNotDeleteTheOwnedFile() throws {
        let model = ServerCommentAttachmentsModel(existing: [attachment("first"), attachment("second")], client: client)
        XCTAssertTrue(model.canSubmit)
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["upload-first", "upload-second"])
        model.removeExisting("first")
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["upload-second"])
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testSubmissionAddsOnlyTheServerConfirmedUploadID() async throws {
        MockURLProtocol.requestHandler = uploadResponse
        let model = ServerCommentAttachmentsModel(existing: [attachment("existing")], client: client)
        await model.add(data: bytes, filename: "notes.bin")
        XCTAssertTrue(model.canSubmit)
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["upload-existing", "confirmed-file"])
        XCTAssertEqual(model.quota?.usedBytes, 44)
        XCTAssertNil(model.drafts.first?.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.compactMap(\.httpMethod), ["GET", "POST", "PUT", "POST"])
    }

    @MainActor
    func testFailedCompletionBlocksPostingAndRetryKeepsTheReservedObject() async throws {
        var failCompletion = true
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix("/complete") == true, failCompletion {
                return try self.response(request, ["error": "Completion unavailable"], status: 503)
            }
            return try self.uploadResponse(request)
        }
        let model = ServerCommentAttachmentsModel(existing: [attachment("existing")], client: client)
        await model.add(data: bytes, filename: "notes.bin")
        XCTAssertFalse(model.canSubmit)
        XCTAssertThrowsError(try model.uploadIDsForSubmission())
        XCTAssertNotNil(model.drafts.first?.error)
        let id = try XCTUnwrap(model.drafts.first?.id)
        failCompletion = false
        await model.retry(id)
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["upload-existing", "confirmed-file"])
        let paths = MockURLProtocol.capturedRequests.compactMap { $0.url?.path }
        XCTAssertEqual(paths.filter { $0 == "/api/workspace/uploads/object" }.count, 1)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "POST" && $0.url?.path == "/api/workspace/uploads" }.count, 1)
        XCTAssertEqual(paths.filter { $0.hasSuffix("/complete") }.count, 2)
    }

    @MainActor
    func testRemovingAFailedDraftEnablesPostingWithoutDeletingStorage() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "PUT" { return try self.response(request, ["error": "Unavailable"], status: 503) }
            return try self.uploadResponse(request)
        }
        let model = ServerCommentAttachmentsModel(client: client)
        await model.add(data: bytes, filename: "notes.bin")
        XCTAssertFalse(model.canSubmit)
        model.removeDraft(try XCTUnwrap(model.drafts.first?.id))
        XCTAssertTrue(model.canSubmit)
        XCTAssertEqual(try model.uploadIDsForSubmission(), [])
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.httpMethod == "DELETE" })
    }

    @MainActor
    func testSizeAndRemainingQuotaComeFromTheFreshServerResponse() async {
        for (data, maximum, used) in [(Data(), 8, 0), (bytes, 3, 0), (bytes, 8, 1022)] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                XCTAssertEqual(request.httpMethod, "GET", "Invalid bytes must not reserve or upload an object")
                return try self.response(request, self.collection(maximum: maximum, used: used))
            }
            let model = ServerCommentAttachmentsModel(client: client)
            await model.add(data: data, filename: "notes.bin")
            XCTAssertNotNil(model.error)
            XCTAssertTrue(model.drafts.isEmpty)
            XCTAssertTrue(model.canSubmit, "A rejected selection must not block a text-only comment")
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        }
    }

    @MainActor
    func testQuotaFailureCanBeRetriedWithoutDiscardingExistingAttachments() async throws {
        let model = ServerCommentAttachmentsModel(existing: [attachment("existing")], client: client)
        MockURLProtocol.stubJSON(["error": "Offline"], statusCode: 503)
        await model.loadQuota()
        XCTAssertFalse(model.canAdd)
        XCTAssertNotNil(model.error)
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["upload-existing"])
        MockURLProtocol.stubJSON(collection())
        await model.loadQuota()
        XCTAssertTrue(model.canAdd)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testChangedAccountCannotSubmitOrImportTheOldDraft() async throws {
        MockURLProtocol.requestHandler = uploadResponse
        let model = ServerCommentAttachmentsModel(existing: [attachment("existing")], client: client)
        await model.add(data: bytes, filename: "notes.bin")
        client.clearTokens()
        client.accessToken = "next-owner"
        XCTAssertFalse(model.canSubmit)
        XCTAssertTrue(model.existing.isEmpty)
        XCTAssertTrue(model.drafts.isEmpty)
        XCTAssertThrowsError(try model.uploadIDsForSubmission())
        let requests = MockURLProtocol.capturedRequests.count
        model.invalidateIfSessionChanged()
        await model.add(data: bytes, filename: "private-old-file.bin")
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, requests)
    }

    @MainActor
    func testSwitchDuringQuotaReadNeverDispatchesTheFileForTheNewAccount() async {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            client.accessToken = "next-owner"
            return try self.response(request, self.collection())
        }
        let model = ServerCommentAttachmentsModel(client: client)
        await model.add(data: bytes, filename: "private.bin")
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertTrue(model.drafts.isEmpty)
        XCTAssertFalse(model.canSubmit)
    }

    @MainActor
    func testDocumentImportReadsTheSelectedFileAndRejectsOversizedFilesBeforeReservation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("notes.bin")
        try bytes.write(to: file)
        MockURLProtocol.requestHandler = uploadResponse
        let model = ServerCommentAttachmentsModel(client: client)
        await model.importFile(file)
        XCTAssertEqual(model.drafts.first?.upload.filename, "notes.bin")
        XCTAssertEqual(try model.uploadIDsForSubmission(), ["confirmed-file"])

        MockURLProtocol.reset()
        MockURLProtocol.stubJSON(collection(maximum: 3))
        let oversized = ServerCommentAttachmentsModel(client: client)
        await oversized.importFile(file)
        XCTAssertTrue(oversized.drafts.isEmpty)
        XCTAssertNotNil(oversized.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    @MainActor
    func testPreviewUsesAuthorizedUploadIDAndRetryShowsTheRealPermissionError() async throws {
        let model = ServerAttachmentPreviewModel(client: client)
        let item = attachment("shared")
        MockURLProtocol.stubJSON(["error": "Forbidden"], statusCode: 403)
        await model.download(item)
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.url)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "attachments.example")
            XCTAssertEqual(request.url?.path, "/api/workspace/uploads/upload-shared/download")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer attachment-owner")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.bytes)
        }
        await model.retry()
        let local = try XCTUnwrap(model.url)
        XCTAssertEqual(try Data(contentsOf: local), bytes)
        XCTAssertNil(model.error)
        model.dismiss()
        XCTAssertNil(model.url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: local.path))
    }

    @MainActor
    func testAccountChangeDeletesTheLocalPreviewAndSuppressesItsRetry() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.bytes)
        }
        let model = ServerAttachmentPreviewModel(client: client)
        await model.download(attachment("shared"))
        let local = try XCTUnwrap(model.url)
        client.clearTokens()
        client.accessToken = "next-owner"
        XCTAssertNil(model.url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: local.path))
        await model.retry()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    private func attachment(_ id: String) -> ServerCommentAttachment {
        ServerCommentAttachment(id: id, uploadId: "upload-\(id)", filename: "\(id).bin",
                                url: "https://untrusted.example/ignored", contentType: "application/octet-stream", size: 4)
    }

    private func collection(maximum: Int = 128, used: Int = 40) -> [String: Any] {
        ["data": [], "pagination": ["page": 1, "pageSize": 1, "total": 0, "totalPages": 0],
         "meta": ["maxFileSizeBytes": maximum, "quotaBytes": 1024, "usedBytes": used]]
    }

    private func uploadResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        switch request.url?.path {
        case "/api/workspace/uploads" where request.httpMethod == "GET":
            return try response(request, collection())
        case "/api/workspace/uploads":
            return try response(request, ["key": key, "url": "https://attachments.example/api/workspace/uploads/object?key=\(key)",
                                          "maxFileSizeBytes": 128, "quotaBytes": 1024, "usedBytes": 40])
        case "/api/workspace/uploads/object":
            return try response(request, ["success": true])
        case "/api/workspace/uploads/complete":
            return try response(request, ["upload": ["id": "confirmed-file", "key": key, "filename": "notes.bin", "size": 4,
                                                     "createdAt": "2026-10-23T02:00:00Z"], "usedBytes": 44, "quotaBytes": 1024])
        default: return try response(request, ["error": "Unexpected route"], status: 404)
        }
    }

    private func response(_ request: URLRequest, _ object: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                         headerFields: ["Content-Type": "application/json"])!, try JSONSerialization.data(withJSONObject: object))
    }
}

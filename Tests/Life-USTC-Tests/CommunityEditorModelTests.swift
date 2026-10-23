import XCTest
@testable import Life_USTC

final class CommunityEditorModelTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2035-09-15T10:30:25.123+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "editor-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://editors.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testDescriptionRequiresResolvedPermissionsBeforeOpeningEditor() async {
        let model = ServerDescriptionModel(target: .course(jwId: 101), client: client)
        XCTAssertFalse(model.beginEditing())
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertFalse(model.beginEditing())
        XCTAssertNotNil(model.loadError)

        MockURLProtocol.stubJSON(description(authenticated: false))
        await model.load()
        XCTAssertEqual(model.description?.content, "Original")
        XCTAssertFalse(model.beginEditing())
        MockURLProtocol.stubJSON(description(suspended: true))
        await model.load()
        XCTAssertFalse(model.beginEditing())
        MockURLProtocol.stubJSON(description())
        await model.load()
        XCTAssertTrue(model.beginEditing())
        XCTAssertEqual(model.draft, "Original")
        XCTAssertFalse(model.canSave)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "POST" }.count, 0)
    }

    @MainActor
    func testDescriptionRefreshRetainsDirtyDraftAndHistoryButGatesFailedPermissions() async {
        let model = ServerDescriptionModel(target: .section(jwId: 202), client: client)
        MockURLProtocol.stubJSON(description(history: 20))
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = "Unsaved notes"
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.draft, "Unsaved notes")
        XCTAssertEqual(model.description?.content, "Original")
        XCTAssertEqual(model.history.count, 20)
        XCTAssertFalse(model.canSave)
        let rejected = await model.save()
        XCTAssertFalse(rejected)

        MockURLProtocol.stubJSON(description(content: "Remote edit", history: 20))
        await model.load()
        XCTAssertEqual(model.description?.content, "Remote edit")
        XCTAssertEqual(model.draft, "Unsaved notes")
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "POST" }.count, 0)
    }

    @MainActor
    func testDescriptionFailedSaveRetainsDraftAndRetryLoadsCanonicalHistory() async throws {
        let model = ServerDescriptionModel(target: .homework(id: "homework"), client: client)
        MockURLProtocol.stubJSON(description())
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = "Edited notes"
        MockURLProtocol.stubJSON(["error": "Write unavailable"], statusCode: 503)
        let failed = await model.save()
        XCTAssertFalse(failed)
        XCTAssertTrue(model.isEditing)
        XCTAssertFalse(model.isSaving)
        XCTAssertEqual(model.draft, "Edited notes")
        XCTAssertEqual(model.description?.content, "Original")
        XCTAssertNotNil(model.saveError)
        XCTAssertTrue(model.canSave)

        let canonical = try JSONSerialization.data(withJSONObject: description(content: "Edited notes", history: 1))
        MockURLProtocol.requestHandler = { request in
            let data = request.httpMethod == "POST" ? Data(#"{"id":"description","updated":true}"#.utf8) : canonical
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isSaving)
        XCTAssertNil(model.saveError)
        XCTAssertEqual(model.description?.content, "Edited notes")
        XCTAssertEqual(model.history.count, 1)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "GET")
    }

    @MainActor
    func testCancelledDescriptionPermissionRefreshKeepsDraftButRequiresSuccessfulRetry() async {
        let model = ServerDescriptionModel(target: .course(jwId: 101), client: client)
        MockURLProtocol.stubJSON(description())
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = "Unsaved notes"
        let refresh = Task { await model.load() }
        refresh.cancel()
        await refresh.value
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.loadError)
        XCTAssertEqual(model.description?.content, "Original")
        XCTAssertEqual(model.draft, "Unsaved notes")
        XCTAssertFalse(model.canSave)
        await model.load()
        XCTAssertTrue(model.canSave)
    }

    @MainActor
    func testDescriptionAllowsEmptyClearAndCountsRawUTF16BeforeServerTrim() async throws {
        let model = ServerDescriptionModel(target: .teacher(id: 303), client: client)
        MockURLProtocol.stubJSON(description())
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = String(repeating: "😀", count: 2000)
        XCTAssertNil(model.validationError)
        model.draft += " "
        XCTAssertNotNil(model.validationError)
        let invalid = await model.save()
        XCTAssertFalse(invalid)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)

        model.draft = ""
        XCTAssertTrue(model.canSave)
        let canonical = try JSONSerialization.data(withJSONObject: description(content: "", history: 1))
        MockURLProtocol.requestHandler = { request in
            let data = request.httpMethod == "POST" ? Data(#"{"id":"description","updated":true}"#.utf8) : canonical
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        let saved = await model.save()
        XCTAssertTrue(saved)
        let write = try XCTUnwrap(MockURLProtocol.capturedRequests.first { $0.httpMethod == "POST" })
        XCTAssertEqual(try requestBody(write)["content"] as? String, "")
        XCTAssertEqual(model.description?.content, "")
    }

    @MainActor
    func testDescriptionAccountReplacementImmediatelyHidesDraftAndPermissions() async throws {
        let model = ServerDescriptionModel(target: .section(jwId: 202), client: client)
        MockURLProtocol.stubJSON(description(history: 1))
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = "Private draft"
        try replaceAccount(client)
        XCTAssertNil(model.description)
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertNil(model.viewer)
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.draft, "")
        let before = MockURLProtocol.capturedRequests.count
        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        MockURLProtocol.stubJSON(description(content: "Current account"))
        await model.load()
        XCTAssertTrue(model.beginEditing())
        XCTAssertEqual(model.draft, "Current account")
    }

    @MainActor
    func testDescriptionLateSaveAndLatePermissionReadCannotReviveFormerOwner() async throws {
        let model = ServerDescriptionModel(target: .course(jwId: 101), client: client)
        MockURLProtocol.stubJSON(description())
        await model.load()
        XCTAssertTrue(model.beginEditing())
        model.draft = "Private draft"
        let client = client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"description","updated":true}"#.utf8))
        }
        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertFalse(model.isSaving)
        XCTAssertFalse(model.isEditing)
        XCTAssertNil(model.description)
        XCTAssertNil(model.saveError)

        let payload = try JSONSerialization.data(withJSONObject: description())
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, payload)
        }
        await model.load()
        XCTAssertNil(model.description)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testHomeworkPermissionsUseSectionJWIDAndBlockUnresolvedOrSuspendedWrites() async {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        model.title = "Assignment"
        XCTAssertFalse(model.canSave)
        let unresolved = await model.save()
        XCTAssertFalse(unresolved)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        MockURLProtocol.stubJSON(homeworkPermissions(suspended: true))
        await model.loadPermissions()
        XCTAssertFalse(model.canSave)
        let suspended = await model.save()
        XCTAssertFalse(suspended)
        let request = MockURLProtocol.capturedRequests.first!
        XCTAssertEqual(query(request), ["sectionJwId": "202", "page": "1", "pageSize": "1"])

        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "POST" }.count, 0)
    }

    @MainActor
    func testHomeworkFailedPermissionRefreshPreservesDraftButBlocksSaveUntilRetry() async {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        model.title = "Draft assignment"
        model.description = "Draft content"
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.loadPermissions()
        XCTAssertEqual(model.title, "Draft assignment")
        XCTAssertEqual(model.description, "Draft content")
        XCTAssertNotNil(model.permissionError)
        XCTAssertFalse(model.canSave)
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        XCTAssertNil(model.permissionError)
        XCTAssertTrue(model.canSave)
    }

    @MainActor
    func testHomeworkTitleOnlyEditPreservesExactDatesAndOmitsUnchangedFields() async throws {
        let original = try decodeHomework(homework())
        let model = ServerHomeworkEditorModel(sectionJwId: 202, homework: original, client: client)
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        XCTAssertFalse(model.hasChanges)
        XCTAssertFalse(model.canSave)
        model.title = "Edited title"
        MockURLProtocol.stubJSON(["success": true, "homework": homework(title: "Edited title")])
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertTrue(model.hasSaved)
        XCTAssertEqual(model.savedHomework?.title, "Edited title")
        XCTAssertEqual(model.submissionDueAt, original.submissionDueAt)
        XCTAssertEqual(try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last)).keys.sorted(), ["title"])
        let before = MockURLProtocol.capturedRequests.count
        let repeated = await model.save()
        XCTAssertFalse(repeated)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
    }

    @MainActor
    func testCancelledHomeworkPermissionRefreshKeepsDraftButRequiresSuccessfulRetry() async {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        model.title = "Unsaved assignment"
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        XCTAssertTrue(model.canSave)
        let refresh = Task { await model.loadPermissions() }
        refresh.cancel()
        await refresh.value
        XCTAssertFalse(model.isLoadingPermissions)
        XCTAssertNil(model.permissionError)
        XCTAssertEqual(model.title, "Unsaved assignment")
        XCTAssertFalse(model.canSave)
        await model.loadPermissions()
        XCTAssertTrue(model.canSave)
    }

    @MainActor
    func testHomeworkClearingPersistedDescriptionAndDatesSendsNull() async throws {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, homework: try decodeHomework(homework()), client: client)
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        model.description = " \n\u{FEFF} "
        model.publishedAt = nil
        model.submissionStartAt = nil
        model.submissionDueAt = nil
        MockURLProtocol.stubJSON(["success": true, "homework": homework()])
        let saved = await model.save()
        XCTAssertTrue(saved)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(Set(body.keys), ["description", "publishedAt", "submissionStartAt", "submissionDueAt"])
        for key in body.keys { XCTAssertTrue(body[key] is NSNull) }
    }

    @MainActor
    func testHomeworkFailedCreateRetainsEveryDraftFieldAndRetryUsesPublicSectionID() async throws {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        let due = Date(timeIntervalSince1970: 2_073_438_625.123)
        model.title = " Assignment "
        model.description = " Detailed notes "
        model.publishedAt = due
        model.submissionStartAt = due
        model.submissionDueAt = due
        model.isMajor = true
        model.requiresTeam = true
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        let failed = await model.save()
        XCTAssertFalse(failed)
        XCTAssertFalse(model.hasSaved)
        XCTAssertFalse(model.isSaving)
        XCTAssertEqual(model.title, " Assignment ")
        XCTAssertEqual(model.description, " Detailed notes ")
        XCTAssertEqual(model.publishedAt, due)
        XCTAssertEqual(model.submissionStartAt, due)
        XCTAssertEqual(model.submissionDueAt, due)
        XCTAssertTrue(model.isMajor)
        XCTAssertTrue(model.requiresTeam)
        XCTAssertTrue(model.canSave)
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(["id": "homework", "homework": homework()], statusCode: 201)
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertNil(model.error)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["sectionJwId"] as? Int, 202)
        XCTAssertNil(body["sectionId"])
        XCTAssertEqual(body["title"] as? String, "Assignment")
        XCTAssertEqual(body["description"] as? String, "Detailed notes")
        XCTAssertEqual(body["submissionStartAt"] as? String, body["submissionDueAt"] as? String)
    }

    @MainActor
    func testHomeworkValidationUsesUTF16AndWholeResultingDateRange() async throws {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, homework: try decodeHomework(homework()), client: client)
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        model.title = " \n\u{FEFF} "
        XCTAssertNotNil(model.validationError)
        model.title = "\u{0085}"
        XCTAssertNil(model.validationError, "ECMAScript does not trim the next-line control character")
        model.title = String(repeating: "😀", count: 101)
        XCTAssertNotNil(model.validationError)
        model.title = " " + String(repeating: "😀", count: 100) + " "
        XCTAssertNil(model.validationError)
        model.description = String(repeating: "😀", count: 2001)
        XCTAssertNotNil(model.validationError)
        model.description = " " + String(repeating: "😀", count: 2000) + " "
        XCTAssertNil(model.validationError)
        model.submissionStartAt = model.submissionDueAt?.addingTimeInterval(1)
        XCTAssertNotNil(model.validationError)
        let invalid = await model.save()
        XCTAssertFalse(invalid)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        model.submissionStartAt = model.submissionDueAt
        XCTAssertNil(model.validationError)
        XCTAssertTrue(model.canSave)
    }

    @MainActor
    func testHomeworkAccountReplacementInvalidatesResolvedPermissionsAndDraftWrites() async throws {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        model.title = "Previous account's draft"
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        XCTAssertTrue(model.canSave)
        try replaceAccount(client)
        XCTAssertFalse(model.isCurrentSession)
        XCTAssertNil(model.viewer)
        XCTAssertFalse(model.canSave)
        let before = MockURLProtocol.capturedRequests.count
        let saved = await model.save()
        await model.loadPermissions()
        XCTAssertFalse(saved)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
    }

    @MainActor
    func testHomeworkLogoutDuringSaveCannotPublishCanonicalItemOrSuccess() async throws {
        let model = ServerHomeworkEditorModel(sectionJwId: 202, client: client)
        model.title = "Draft"
        MockURLProtocol.stubJSON(homeworkPermissions())
        await model.loadPermissions()
        let data = try JSONSerialization.data(withJSONObject: ["id": "homework", "homework": homework()])
        let client = client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 201,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertFalse(model.hasSaved)
        XCTAssertFalse(model.isSaving)
        XCTAssertNil(model.savedHomework)
        XCTAssertNil(model.error)
    }

    private func viewer(authenticated: Bool = true, suspended: Bool = false) -> [String: Any] {
        ["userId": authenticated ? "owner" as Any : NSNull(), "name": NSNull(), "image": NSNull(),
         "isAdmin": false, "isAuthenticated": authenticated, "isSuspended": suspended,
         "suspensionReason": NSNull(), "suspensionExpiresAt": NSNull()]
    }

    private func description(content: String = "Original", authenticated: Bool = true,
                             suspended: Bool = false, history: Int = 0) -> [String: Any] {
        ["description": ["id": "description", "content": content, "renderedHtml": "<p>\(content)</p>",
                         "updatedAt": timestamp, "lastEditedAt": timestamp, "lastEditedBy": NSNull()],
         "history": (0..<history).map { ["id": "edit-\($0)", "createdAt": timestamp,
                                         "previousContent": NSNull(), "nextContent": content,
                                         "editor": NSNull()] as [String: Any] },
         "viewer": viewer(authenticated: authenticated, suspended: suspended)]
    }

    private func homeworkPermissions(suspended: Bool = false) -> [String: Any] {
        ["data": [], "pagination": ["page": 1, "pageSize": 1, "total": 0, "totalPages": 0],
         "meta": ["viewer": viewer(suspended: suspended)]]
    }

    private func homework(title: String = "Original assignment") -> [String: Any] {
        ["id": "homework", "sectionId": 7, "title": title, "isMajor": false,
         "requiresTeam": false, "completionRequired": true,
         "publishedAt": timestamp, "submissionStartAt": timestamp, "submissionDueAt": timestamp,
         "createdAt": timestamp, "updatedAt": timestamp,
         "description": ["id": "description", "content": "Original notes"]]
    }

    private func decodeHomework(_ json: [String: Any]) throws -> ServerHomework {
        try client.decoder.decode(ServerHomework.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func replaceAccount(_ client: ServerClient) throws {
        try client.acceptAuthorization(OAuthTokenResponse(
            accessToken: "next-owner", tokenType: "Bearer", expiresIn: nil,
            refreshToken: nil, scope: nil
        ), expectedRevision: client.sessionRevision)
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
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

import XCTest
@testable import Life_USTC

final class CommentModelTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "comment-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://community.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testPublicIdentifiersAndCompletePages() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(values["targetType"], "section")
            XCTAssertEqual(values["sectionJwId"], "42001")
            XCTAssertNil(values["targetId"])
            XCTAssertNil(values["sectionId"])
            let page = Int(values["page"]!)!
            return try self.response(request, self.page([self.comment("comment-\(page)")], page: page, totalPages: 2))
        }
        let result = try await client.fetchComments(targetType: "section", sectionJwId: 42001)
        XCTAssertEqual(result.comments.map(\.id), ["comment-1", "comment-2"])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testAccountChangeDuringPageReadDiscardsEntireCollection() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return try self.response(request, self.page([self.comment("former-owner")], totalPages: 2))
        }
        do {
            _ = try await client.fetchComments(targetType: "section", sectionJwId: 42001)
            XCTFail("A previous account's collection must be discarded")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    @MainActor
    func testRefreshFailureRetainsCompleteSnapshotAndCanRetry() async {
        let model = CommentListViewModel(targetType: "section", sectionJwId: 42001, client: client)
        MockURLProtocol.stubJSON(page([comment("confirmed")]))
        await model.load()
        MockURLProtocol.requestHandler = { request in
            let isFirst = request.url!.query!.contains("page=1&")
            return try self.response(request,
                isFirst ? self.page([self.comment("partial")], totalPages: 2) : ["error": "Unavailable"],
                status: isFirst ? 200 : 503)
        }
        await model.load()
        XCTAssertEqual(model.comments.map(\.id), ["confirmed"])
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.canContribute)
        MockURLProtocol.stubJSON(page([comment("recovered")]))
        await model.load()
        XCTAssertEqual(model.comments.map(\.id), ["recovered"])
        XCTAssertNil(model.error)
        XCTAssertTrue(model.canContribute)
    }

    @MainActor
    func testCommentBodyUsesServerUTF16LimitAndTrimsWhitespace() {
        XCTAssertNotNil(CommentListViewModel.bodyValidationError(" \n\t"))
        XCTAssertNil(CommentListViewModel.bodyValidationError(String(repeating: "a", count: 8_000)))
        XCTAssertNotNil(CommentListViewModel.bodyValidationError(String(repeating: "a", count: 8_001)))
        XCTAssertNil(CommentListViewModel.bodyValidationError(String(repeating: "😀", count: 4_000)))
        XCTAssertNotNil(CommentListViewModel.bodyValidationError(String(repeating: "😀", count: 4_001)))
        XCTAssertNil(CommentListViewModel.bodyValidationError(" \nComment\n "))
    }

    @MainActor
    func testInvalidBodyNeverDispatchesCreateOrUpdate() async {
        let model = CommentListViewModel(targetType: "section", sectionJwId: 42001, client: client)
        MockURLProtocol.stubJSON(page([comment("existing")]))
        await model.load()
        let count = MockURLProtocol.capturedRequests.count
        do {
            try await model.createComment(body: "\n", visibility: "public", isAnonymous: false,
                                          parentId: nil, attachmentIds: [], expectedRevision: client.sessionRevision)
            XCTFail("Blank comments must be rejected before dispatch")
        } catch { }
        do {
            try await model.updateComment(model.comments[0], body: String(repeating: "😀", count: 4_001),
                                          visibility: "public", isAnonymous: false)
            XCTFail("Overlong comments must be rejected before dispatch")
        } catch { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, count)
    }

    @MainActor
    func testFocusedThreadUsesResolvedTargetForRepliesAndPreservesHiddenAncestor() async throws {
        let model = CommentListViewModel(targetType: "", focusedCommentID: "focus", client: client)
        var ancestor = comment("hidden-root")
        ancestor["body"] = ""
        ancestor["isAncestryPlaceholder"] = true
        ancestor["replies"] = [comment("focus")]
        let thread: [String: Any] = [
            "thread": [ancestor], "focusId": "focus", "hiddenCount": 1,
            "viewer": viewer(), "target": ["homeworkId": "homework-9", "sectionId": 17]
        ]
        MockURLProtocol.stubJSON(thread)
        await model.load()
        XCTAssertTrue(model.canContribute)
        XCTAssertEqual(model.hiddenCount, 1)
        XCTAssertEqual(model.comments.first?.isAncestryPlaceholder, true)
        XCTAssertEqual(model.comments.first?.children?.first?.id, "focus")
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST" {
                let body = try self.requestBody(request)
                XCTAssertEqual(body["targetType"] as? String, "homework")
                XCTAssertEqual(body["targetId"] as? String, "homework-9")
                XCTAssertEqual(body["parentId"] as? String, "focus")
                XCTAssertEqual(body["body"] as? String, "Reply")
                return try self.response(request, ["id": "new-reply"], status: 201)
            }
            XCTAssertEqual(request.url?.path, "/api/community/comments/focus")
            return try self.response(request, thread)
        }
        try await model.createComment(body: " \nReply \n", visibility: "public", isAnonymous: false,
                                      parentId: "focus", attachmentIds: [], expectedRevision: client.sessionRevision)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)
    }

    @MainActor
    func testFocusedThreadCannotRestoreOldAccountAfterReplacement() async throws {
        let model = CommentListViewModel(targetType: "", focusedCommentID: "focus", client: client)
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return try self.response(request, [
                "thread": [self.comment("private")], "focusId": "focus", "hiddenCount": 0,
                "viewer": self.viewer(), "target": ["sectionId": 17]
            ])
        }
        await model.load()
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertNil(model.viewer)
        XCTAssertFalse(model.canContribute)
    }

    @MainActor
    func testPrivateCommentsDisappearImmediatelyWhenSessionChanges() async throws {
        let model = CommentListViewModel(targetType: "section", sectionJwId: 42001, client: client)
        MockURLProtocol.stubJSON(page([comment("private")]))
        await model.load()
        XCTAssertTrue(model.canContribute)
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertNil(model.viewer)
        XCTAssertFalse(model.canContribute)
        MockURLProtocol.stubJSON(page([comment("second-private")]))
        await model.load()
        client.clearTokens()
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertNil(model.viewer)
        MockURLProtocol.stubJSON(page([comment("public")], authenticated: false))
        await model.load()
        XCTAssertEqual(model.comments.map(\.id), ["public"])
        XCTAssertFalse(model.canContribute)
    }

    @MainActor
    func testSuspensionBlocksContributionAndPreservesReason() async {
        let model = CommentListViewModel(targetType: "course", courseJwId: 9001, client: client)
        MockURLProtocol.stubJSON(page([], suspended: true))
        await model.load()
        XCTAssertEqual(model.viewer?.suspensionReason, "Posting paused")
        XCTAssertFalse(model.canContribute)
        let count = MockURLProtocol.capturedRequests.count
        do {
            try await model.createComment(body: "Test", visibility: "public", isAnonymous: false,
                                          parentId: nil, attachmentIds: [], expectedRevision: client.sessionRevision)
            XCTFail("Suspended viewers cannot contribute")
        } catch { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, count)
    }

    @MainActor
    func testCreateUsesPublicTargetAndOnlyCompletedUploadIDs() async throws {
        let model = CommentListViewModel(targetType: "homework", homeworkId: "homework-7", client: client)
        MockURLProtocol.stubJSON(page([]))
        await model.load()
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST" {
                let body = try self.requestBody(request)
                XCTAssertEqual(body["homeworkId"] as? String, "homework-7")
                XCTAssertEqual(body["attachmentIds"] as? [String], ["completed-upload-1"])
                XCTAssertEqual(body["parentId"] as? String, "root-1")
                XCTAssertEqual(body["visibility"] as? String, "logged_in_only")
                XCTAssertNil(body["sectionId"])
                return try self.response(request, ["id": "created"], status: 201)
            }
            return try self.response(request, self.page([self.comment("created")]))
        }
        try await model.createComment(body: "Attachment", visibility: "logged_in_only", isAnonymous: false,
                                      parentId: "root-1", attachmentIds: ["completed-upload-1"],
                                      expectedRevision: client.sessionRevision)
        XCTAssertEqual(model.comments.map(\.id), ["created"])
    }

    @MainActor
    func testOldEditorCannotWriteThroughReplacementAccount() async throws {
        let model = CommentListViewModel(targetType: "section", sectionJwId: 42001, client: client)
        MockURLProtocol.stubJSON(page([comment("existing")]))
        await model.load()
        let oldRevision = client.sessionRevision
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: oldRevision)
        await model.load()
        let count = MockURLProtocol.capturedRequests.count
        do {
            try await model.updateComment(model.comments[0], body: "Old draft", visibility: "public",
                                          isAnonymous: false, expectedRevision: oldRevision)
            XCTFail("An old editor must never use a new account")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, count)
    }

    @MainActor
    func testLateReplyPageCannotRestoreFormerAccountComments() async throws {
        let model = CommentListViewModel(targetType: "section", sectionJwId: 42001, client: client)
        MockURLProtocol.stubJSON(page([comment("root", cursor: "cursor-1")]))
        await model.load()
        let root = model.comments[0]
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return try self.response(request, [
                "rootId": "root", "thread": [self.comment("root")],
                "nextCursor": NSNull(), "viewer": self.viewer()
            ])
        }
        await model.loadMoreReplies(for: root)
        XCTAssertTrue(model.comments.isEmpty)
        XCTAssertNil(model.viewer)
    }

    private func response(_ request: URLRequest, _ body: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: body))
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
                XCTAssertGreaterThanOrEqual(count, 0)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func comment(_ id: String, cursor: String? = nil) -> [String: Any] {
        ["id": id, "body": "Comment \(id)", "visibility": "logged_in_only", "isAnonymous": false,
         "createdAt": "2026-10-23T12:00:00+08:00", "updatedAt": "2026-10-23T12:00:00+08:00",
         "reactions": [], "repliesNextCursor": cursor as Any? ?? NSNull()]
    }

    private func viewer(authenticated: Bool = true, suspended: Bool = false) -> [String: Any] {
        ["userId": authenticated ? "owner" : NSNull(), "isAdmin": false,
         "isAuthenticated": authenticated, "isSuspended": suspended,
         "suspensionReason": suspended ? "Posting paused" : NSNull()]
    }

    private func page(_ comments: [[String: Any]], page: Int = 1, totalPages: Int = 1,
                      authenticated: Bool = true, suspended: Bool = false) -> [String: Any] {
        ["data": comments,
         "pagination": ["page": page, "pageSize": 100, "total": comments.count, "totalPages": totalPages],
         "meta": ["hiddenCount": 0, "viewer": viewer(authenticated: authenticated, suspended: suspended),
                  "target": ["type": "section", "targetId": 7]]]
    }
}

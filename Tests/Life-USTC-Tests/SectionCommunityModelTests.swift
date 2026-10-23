import XCTest
@testable import Life_USTC

final class SectionCommunityModelTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2035-09-15T10:30:25+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "community-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://sections.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testAnonymousSectionListExhaustsPagesUsingJWIDAndRetainsDeletedState() async throws {
        client.clearTokens()
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.requestHandler = { request in
            let query = self.query(request)
            let page = Int(query["page"] ?? "0")!
            XCTAssertEqual(query["sectionJwId"], "202")
            XCTAssertNil(query["sectionId"])
            XCTAssertEqual(query["pageSize"], "100")
            XCTAssertEqual(query["includeDeleted"], "true")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let data = ((page - 1) * 100..<min(page * 100, 101)).map {
                self.homework("homework-\($0)", deleted: $0 == 100)
            }
            return try self.response(request, self.page(data, page: page, total: 101, totalPages: 2,
                                                        viewer: self.viewer(authenticated: false)))
        }
        await model.load()
        XCTAssertEqual(model.homeworks.count, 101)
        XCTAssertEqual(model.homeworks.first?.id, "homework-0")
        XCTAssertTrue(model.isDeleted(try XCTUnwrap(model.homeworks.last)))
        XCTAssertFalse(model.canCreate)
        XCTAssertFalse(model.canEdit(try XCTUnwrap(model.homeworks.first)))
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    @MainActor
    func testFailedLaterPagePreservesPreviousCompleteListAndBlocksWritesUntilRetry() async {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(page([homework("previous")]))
        await model.load()
        XCTAssertTrue(model.canCreate)
        MockURLProtocol.requestHandler = { request in
            if self.query(request)["page"] == "2" {
                return try self.response(request, ["error": "Later page unavailable"], status: 503)
            }
            return try self.response(request, self.page([self.homework("partial")], total: 101, totalPages: 2))
        }
        await model.load()
        XCTAssertEqual(model.homeworks.map(\.id), ["previous"])
        XCTAssertNotNil(model.loadError)
        XCTAssertFalse(model.canCreate)
        MockURLProtocol.stubJSON(page([homework("current")]))
        await model.load()
        XCTAssertEqual(model.homeworks.map(\.id), ["current"])
        XCTAssertNil(model.loadError)
        XCTAssertTrue(model.canCreate)
    }

    @MainActor
    func testOnlyCreatorCanDeleteWhileActiveWritersCanEditAndSuspendedUsersCannot() async throws {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        let items = [homework("own"), homework("other", owner: "other-owner"), homework("deleted", deleted: true)]
        MockURLProtocol.stubJSON(page(items))
        await model.load()
        XCTAssertTrue(model.canDelete(try XCTUnwrap(model.homeworks.first)))
        XCTAssertTrue(model.canEdit(model.homeworks[1]))
        XCTAssertFalse(model.canDelete(model.homeworks[1]))
        XCTAssertFalse(model.canEdit(model.homeworks[2]))

        MockURLProtocol.stubJSON(page(items, viewer: viewer(userID: "admin", admin: true)))
        await model.load()
        XCTAssertTrue(model.canEdit(model.homeworks[0]))
        XCTAssertFalse(model.canDelete(model.homeworks[0]), "The community delete API does not grant moderation authority")
        let before = MockURLProtocol.capturedRequests.count
        let denied = await model.delete(id: "own")
        XCTAssertFalse(denied)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        MockURLProtocol.stubJSON(page(items, viewer: viewer(suspended: true)))
        await model.load()
        XCTAssertFalse(model.canCreate)
        var unresolved = viewer()
        unresolved.removeValue(forKey: "isSuspended")
        MockURLProtocol.stubJSON(page(items, viewer: unresolved))
        await model.load()
        XCTAssertFalse(model.canCreate)
    }

    @MainActor
    func testCancelledRefreshKeepsPublicRowsButInvalidatesWritePermissions() async {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(page([homework("homework")]))
        await model.load()
        XCTAssertTrue(model.canCreate)
        let refresh = Task { await model.load() }
        refresh.cancel()
        await refresh.value
        XCTAssertEqual(model.homeworks.map(\.id), ["homework"])
        XCTAssertFalse(model.canCreate)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedDeletionKeepsRowAndRetryReloadsCanonicalDeletedState() async throws {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(page([homework("homework")]))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        let failed = await model.delete(id: "homework")
        XCTAssertFalse(failed)
        XCTAssertFalse(model.isDeleted(try XCTUnwrap(model.homeworks.first)))
        XCTAssertTrue(model.canRetryDelete)
        XCTAssertNotNil(model.deleteError)
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "DELETE"
                ? try self.response(request, ["success": true])
                : try self.response(request, self.page([self.homework("homework", deleted: true)]))
        }
        let deleted = await model.retryDelete()
        XCTAssertTrue(deleted)
        XCTAssertTrue(model.isDeleted(try XCTUnwrap(model.homeworks.first)))
        XCTAssertNotNil(model.homeworks.first?.deletedAt)
        XCTAssertFalse(model.canRetryDelete)
        XCTAssertNil(model.deleteError)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "DELETE" }.count, 2)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "GET")
    }

    @MainActor
    func testConfirmedDeletionRemainsDeletedWhenCanonicalReloadFails() async throws {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(page([homework("homework")]))
        await model.load()
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "DELETE"
                ? try self.response(request, ["success": true])
                : try self.response(request, ["error": "Read unavailable"], status: 503)
        }
        let deleted = await model.delete(id: "homework")
        XCTAssertTrue(deleted)
        let item = try XCTUnwrap(model.homeworks.first)
        XCTAssertTrue(model.isDeleted(item))
        XCTAssertNil(item.deletedAt, "A failed read must not invent a server deletion timestamp")
        XCTAssertFalse(model.canEdit(item))
        XCTAssertFalse(model.canRetryDelete)
        XCTAssertNil(model.deleteError)
        XCTAssertNotNil(model.loadError)
    }

    @MainActor
    func testAccountReplacementImmediatelyHidesPermissionsAndRejectsLateDeletionSuccess() async throws {
        let model = ServerSectionHomeworksModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(page([homework("homework")]))
        await model.load()
        let old = try XCTUnwrap(model.homeworks.first)
        try replaceAccount()
        XCTAssertTrue(model.homeworks.isEmpty)
        XCTAssertNil(model.viewer)
        XCTAssertFalse(model.canDelete(old))
        let before = MockURLProtocol.capturedRequests.count
        let denied = await model.delete(id: old.id)
        XCTAssertFalse(denied)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        await model.load()
        let client = client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return try self.response(request, ["success": true])
        }
        let late = await model.delete(id: old.id)
        XCTAssertFalse(late)
        XCTAssertTrue(model.homeworks.isEmpty)
        XCTAssertNil(model.deleteError)
        XCTAssertFalse(model.canRetryDelete)
    }

    @MainActor
    func testPublicHistoryPreservesLatestFiftyEntriesAndRetainsSameSessionReadFailure() async {
        client.clearTokens()
        let model = ServerHomeworkHistoryModel(sectionJwId: 202, client: client)
        MockURLProtocol.stubJSON(["auditLogs": audits()])
        await model.load()
        XCTAssertEqual(model.history.count, 50)
        XCTAssertEqual(model.history.first?.action, .deleted)
        XCTAssertEqual(model.history.last?.id, "audit-49")
        XCTAssertNil(model.history.first?.actor)
        XCTAssertEqual(query(MockURLProtocol.capturedRequests.first!), ["sectionJwId": "202"])
        XCTAssertNil(MockURLProtocol.capturedRequests.first?.value(forHTTPHeaderField: "Authorization"))
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.history.count, 50)
        XCTAssertNotNil(model.error)
        client.clearTokens()
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testFocusedHomeworkHistoryRequiresActualAuditPayload() async {
        let model = ServerHomeworkHistoryModel(sectionJwId: 202, homeworkID: "homework", client: client)
        MockURLProtocol.stubJSON(["homework": homework("homework")])
        await model.load()
        XCTAssertNotNil(model.error, "Missing auditLogs must not look like an empty history")
        MockURLProtocol.stubJSON(["homework": homework("homework"), "auditLogs": audits()])
        await model.load()
        XCTAssertEqual(model.history.count, 50)
        XCTAssertNil(model.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path, "/api/community/section-homeworks/homework")
    }

    @MainActor
    func testAnonymousHomeworkDetailReadsPublicContentWithoutCompletionOrEditingWrites() async {
        client.clearTokens()
        let model = ServerHomeworkDetailModel(homeworkID: "homework", client: client)
        MockURLProtocol.stubJSON(["homework": homework("homework")])
        await model.load()
        await model.loadPermissions()
        XCTAssertEqual(model.homework?.title, "Shared homework")
        XCTAssertFalse(model.canEdit)
        let toggled = await model.toggleCompletion()
        XCTAssertFalse(toggled)
        XCTAssertFalse(model.canRetryMutation)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertNil(MockURLProtocol.capturedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    @MainActor
    func testHomeworkDetailRequiresResolvedSectionPermissionsBeforeEditing() async {
        let model = ServerHomeworkDetailModel(homeworkID: "homework", client: client)
        MockURLProtocol.stubJSON(["homework": homework("homework")])
        await model.load()
        XCTAssertFalse(model.canEdit)
        MockURLProtocol.stubJSON(page([], pageSize: 1))
        await model.loadPermissions()
        XCTAssertTrue(model.canEdit)
        XCTAssertEqual(query(MockURLProtocol.capturedRequests.last!), ["sectionId": "7", "page": "1", "pageSize": "1"])
        MockURLProtocol.stubJSON(["error": "Permissions unavailable"], statusCode: 503)
        await model.loadPermissions()
        XCTAssertFalse(model.canEdit)
        XCTAssertNotNil(model.permissionError)
        XCTAssertNotNil(model.homework)
        MockURLProtocol.stubJSON(page([], pageSize: 1, viewer: viewer(suspended: true)))
        await model.loadPermissions()
        XCTAssertFalse(model.canEdit)
        XCTAssertNil(model.permissionError)
    }

    @MainActor
    func testLateDetailPermissionResponseCannotRestoreFormerAccountEditor() async throws {
        let model = ServerHomeworkDetailModel(homeworkID: "homework", client: client)
        MockURLProtocol.stubJSON(["homework": homework("homework")])
        await model.load()
        let client = client!
        let payload = page([], pageSize: 1)
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return try self.response(request, payload)
        }
        await model.loadPermissions()
        XCTAssertFalse(model.canEdit)
        XCTAssertNil(model.viewer)
        XCTAssertNil(model.homework)
        XCTAssertNil(model.permissionError)
        XCTAssertFalse(model.isLoadingPermissions)
    }

    private func viewer(userID: String = "owner", authenticated: Bool = true,
                        admin: Bool = false, suspended: Bool = false) -> [String: Any] {
        ["userId": authenticated ? userID as Any : NSNull(), "isAdmin": admin,
         "isAuthenticated": authenticated, "isSuspended": suspended]
    }

    private func homework(_ id: String, owner: String = "owner", deleted: Bool = false) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": "Shared homework", "isMajor": false,
         "requiresTeam": false, "completionRequired": true, "createdAt": timestamp, "updatedAt": timestamp,
         "createdById": owner, "deletedAt": deleted ? timestamp as Any : NSNull(),
         "section": ["id": 7, "jwId": 202, "code": "MATH101.01", "courseId": 3,
                     "course": ["id": 3, "jwId": 101, "code": "MATH101", "nameCn": "数学"]]]
    }

    private func page(_ data: [[String: Any]], page: Int = 1, pageSize: Int = 100,
                      total: Int? = nil, totalPages: Int = 1, viewer: [String: Any]? = nil) -> [String: Any] {
        ["data": data, "pagination": ["page": page, "pageSize": pageSize,
                                      "total": total ?? data.count, "totalPages": totalPages],
         "meta": ["viewer": viewer ?? self.viewer()]]
    }

    private func audits() -> [[String: Any]] {
        (0..<50).map {
            ["id": "audit-\($0)", "action": $0 == 0 ? "deleted" : "updated",
             "titleSnapshot": "Previous title", "createdAt": timestamp,
             "sectionId": 7, "homeworkId": "homework", "actorId": NSNull(), "actor": NSNull()]
        }
    }

    private func replaceAccount() throws {
        try client.acceptAuthorization(OAuthTokenResponse(
            accessToken: "next-owner", tokenType: "Bearer", expiresIn: nil,
            refreshToken: nil, scope: nil
        ), expectedRevision: client.sessionRevision)
    }

    private func response(_ request: URLRequest, _ json: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: json))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }
}

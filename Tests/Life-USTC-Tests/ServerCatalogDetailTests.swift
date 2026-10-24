import XCTest
@testable import Life_USTC

final class ServerCatalogDetailTests: XCTestCase {
    private var client: ServerClient!
    private var tokens: MockTokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        tokens = MockTokenStore()
        tokens.accessToken = "catalog-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://catalog.example")!,
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

    func testCourseJWIDAndTeacherIDScopesLoadEveryHistoryPage() async throws {
        for scope in [ServerCatalogSectionScope.course(11), .teacher(3)] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                let query = self.query(request)
                XCTAssertEqual(query["pageSize"], "100")
                switch scope {
                case .course(let id):
                    XCTAssertEqual(request.url?.path, "/api/catalog/courses/\(id)/sections")
                case .teacher(let id):
                    XCTAssertEqual(request.url?.path, "/api/catalog/teachers/\(id)/sections")
                }
                XCTAssertEqual(Set(query.keys), ["page", "pageSize"])
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer catalog-owner")
                return try self.page(request)
            }
            let sections = try await client.fetchAllCatalogSections(scope: scope)
            XCTAssertEqual(sections.map(\.id), Array(1...205))
            XCTAssertEqual(sections.last?.jwId, 1205)
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)
        }
    }

    func testPublicSectionHistoryRemainsAvailableWithoutSignIn() async throws {
        client.clearTokens()
        MockURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return try self.page(request, total: 21)
        }
        let sections = try await client.fetchAllCatalogSections(scope: .teacher(3))
        XCTAssertEqual(sections.count, 21)
    }

    func testIncorrectPageDoesNotBecomeACompleteSectionList() async throws {
        MockURLProtocol.requestHandler = { request in
            try self.response(request, [
                "data": [self.section(1)],
                "pagination": ["page": 1, "pageSize": 100, "total": 101, "totalPages": 2],
            ])
        }
        do {
            _ = try await client.fetchAllCatalogSections(scope: .course(11))
            XCTFail("A repeated server page must not produce duplicated complete history")
        } catch ServerError.serverError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testBackendChangeOnLaterPageCancelsTheWholeSectionRead() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            if self.query(request)["page"] == "2" {
                client.reconfigure(baseURL: URL(string: "https://different.example")!)
            }
            return try self.page(request)
        }
        do {
            _ = try await client.fetchAllCatalogSections(scope: .teacher(3))
            XCTFail("The result must not combine two backend catalogs")
        } catch is CancellationError { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        XCTAssertTrue(MockURLProtocol.capturedRequests.allSatisfy { $0.url?.host == "catalog.example" })
    }

    @MainActor
    func testFirstLoadFailureDoesNotPublishTheSuccessfulFirstPageAndCanRetry() async {
        var failing = true
        MockURLProtocol.requestHandler = { request in
            if self.query(request)["page"] == "2", failing {
                return try self.response(request, ["error": "Section history unavailable"], status: 503)
            }
            return try self.page(request)
        }
        let model = ServerCatalogSectionsModel(client: client)
        await model.load(scope: .course(11))
        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertEqual(model.error, "Section history unavailable")
        XCTAssertFalse(model.isLoading)
        failing = false
        await model.load(scope: .course(11))
        XCTAssertEqual(model.sections.count, 205)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testReloadFailurePreservesOnlyTheSameScopeCompleteSnapshot() async {
        MockURLProtocol.requestHandler = { request in try self.page(request, total: 21) }
        let model = ServerCatalogSectionsModel(client: client)
        await model.load(scope: .course(11))
        XCTAssertEqual(model.sections.count, 21)
        MockURLProtocol.stubJSON(["error": "Offline"], statusCode: 503)
        await model.load(scope: .course(11))
        XCTAssertEqual(model.sections.count, 21)
        XCTAssertEqual(model.error, "Offline")
        await model.load(scope: .teacher(3))
        XCTAssertTrue(model.sections.isEmpty, "A teacher must not inherit another course's previous history")
        XCTAssertEqual(model.error, "Offline")
    }

    @MainActor
    func testCatalogSnapshotIsHiddenImmediatelyAfterSessionChange() async {
        MockURLProtocol.requestHandler = { request in try self.page(request, total: 21) }
        let model = ServerCatalogSectionsModel(client: client)
        await model.load(scope: .course(11))
        XCTAssertEqual(model.sections.count, 21)
        client.clearTokens()
        XCTAssertTrue(model.sections.isEmpty)
    }

    func testStaleRevisionRejectsEveryMembershipWriteBeforeSendingRequest() async throws {
        let formerRevision = client.sessionRevision
        client.clearTokens()
        tokens.accessToken = "another-owner"
        for operation in ["append", "remove", "kind"] {
            do {
                switch operation {
                case "append": try await client.appendSectionSubscription(sectionID: 7, expectedRevision: formerRevision)
                case "remove": try await client.removeSectionSubscription(sectionID: 7, expectedRevision: formerRevision)
                default: try await client.updateSectionSubscriptionKind(jwID: 42, kind: .auditor, expectedRevision: formerRevision)
                }
                XCTFail("Queued \(operation) must not act as a newly signed-in account")
            } catch is CancellationError { }
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    func testAlreadyCancelledMembershipWriteDoesNotReachTheNetwork() async throws {
        let client = self.client!
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await client.appendSectionSubscription(sectionID: 7, expectedRevision: client.sessionRevision)
        }
        do {
            try await task.value
            XCTFail("Cancellation must be checked before dispatch")
        } catch is CancellationError { }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testOldSectionAndSubscriptionModelsCannotMutateANewAccount() async throws {
        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/api/catalog/sections/42":
                return try self.response(request, ["id": 7, "jwId": 42, "code": "MATH101.01"])
            case "/api/catalog/sections/42/schedules":
                return try self.response(request, ["data": [], "pagination": ["page": 1, "pageSize": 100, "total": 0, "totalPages": 0]])
            default:
                return try self.response(request, ["subscription": ["sections": [
                    ["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular"],
                ]]])
            }
        }
        let detail = ServerSectionDetailModel(jwId: 42, client: client)
        let subscriptions = ServerSubscriptionsModel(client: client)
        await detail.load()
        await subscriptions.load()
        let previous = try XCTUnwrap(subscriptions.sections.first)
        XCTAssertTrue(detail.subscriptionReadSucceeded)
        client.clearTokens()
        tokens.accessToken = "another-owner"
        MockURLProtocol.reset()
        await detail.toggleSubscription()
        await detail.setKind(.auditor)
        await subscriptions.remove(previous)
        await subscriptions.setKind(.auditor, for: previous)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    private func section(_ id: Int) -> [String: Any] {
        ["id": id, "jwId": id + 1000, "code": "MATH101.\(id)",
         "course": ["id": 11, "jwId": 1001, "code": "MATH101", "nameCn": "Calculus"],
         "semester": ["id": 1, "code": "2026-FALL", "nameCn": "Autumn 2026"],
         "teachers": [["id": 3, "nameCn": "Teacher"]]]
    }

    private func page(_ request: URLRequest, total: Int = 205) throws -> (HTTPURLResponse, Data) {
        let page = Int(query(request)["page"] ?? "1")!
        let first = (page - 1) * 100 + 1
        let last = min(page * 100, total)
        return try response(request, [
            "data": first <= last ? (first...last).map(section) : [],
            "pagination": ["page": page, "pageSize": 100, "total": total, "totalPages": (total + 99) / 100],
        ])
    }

    private func response(_ request: URLRequest, _ body: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: body))
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
}

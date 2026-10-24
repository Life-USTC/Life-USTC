import XCTest
@testable import Life_USTC

final class ServerAccountActivityTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "activity-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://account.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testActivityUsesCurrentAuthorizationAndOpaqueCursor() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/account/client-activity")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer activity-owner")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.count, 2)
            XCTAssertEqual(query.first { $0.name == "limit" }?.value, "30")
            XCTAssertEqual(query.first { $0.name == "cursor" }?.value, "2026-10-23T12:00:00.000Z|audit-001")
            return try self.response(request, self.page(["audit-002"]))
        }
        let page = try await client.fetchAccountActivity(cursor: "2026-10-23T12:00:00.000Z|audit-001")
        XCTAssertEqual(page.items.map(\.id), ["audit-002"])
        XCTAssertEqual(page.items.first?.outcome, .success)
        XCTAssertNil(page.nextCursor)
    }

    @MainActor
    func testNextPageFailurePreservesHistoryAndRetriesSameCursor() async {
        let model = ServerAccountActivityModel(client: client)
        MockURLProtocol.stubJSON(page(["first"], next: "cursor-1"))
        await model.load()
        XCTAssertTrue(model.hasMore)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load(refresh: false)
        XCTAssertEqual(model.items.map(\.id), ["first"])
        XCTAssertTrue(model.hasMore)
        XCTAssertNotNil(model.error)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(self.cursor(request), "cursor-1")
            return try self.response(request, self.page(["second"]))
        }
        await model.retry()
        XCTAssertEqual(model.items.map(\.id), ["first", "second"])
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testRefreshFailureRetriesFirstPageWhileRetainingHistory() async {
        let model = ServerAccountActivityModel(client: client)
        MockURLProtocol.stubJSON(page(["previous"], next: "cursor-1"))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.items.map(\.id), ["previous"])
        MockURLProtocol.requestHandler = { request in
            XCTAssertNil(self.cursor(request))
            return try self.response(request, self.page(["newer", "previous"]))
        }
        await model.retry()
        XCTAssertEqual(model.items.map(\.id), ["newer", "previous"])
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testAccountActivityIsPrivateAcrossAccountReplacementAndLogout() async throws {
        let model = ServerAccountActivityModel(client: client)
        MockURLProtocol.stubJSON(page(["first-owner"], next: "private-cursor"))
        await model.load()
        XCTAssertEqual(model.items.map(\.id), ["first-owner"])
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.hasMore)
        MockURLProtocol.requestHandler = { request in
            XCTAssertNil(self.cursor(request))
            return try self.response(request, self.page(["second-owner"]))
        }
        await model.load()
        XCTAssertEqual(model.items.map(\.id), ["second-owner"])
        client.clearTokens()
        XCTAssertTrue(model.items.isEmpty)
        let count = MockURLProtocol.capturedRequests.count
        await model.load()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, count)
    }

    private func cursor(_ request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "cursor" }?.value
    }

    private func page(_ ids: [String], next: String? = nil) -> [String: Any] {
        ["items": ids.map { ["id": $0, "action": "comment_create", "outcome": "success",
                            "channel": "rest", "createdAt": "2026-10-23T12:00:00+08:00",
                            "targetType": "Comment"] },
         "nextCursor": next as Any? ?? NSNull()]
    }

    private func response(_ request: URLRequest, _ body: [String: Any]) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: body))
    }
}

import XCTest
@testable import Life_USTC

final class WorkspaceHomeModelTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "workspace-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://workspace.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: "serverBaseURL")
        client = nil
    }

    @MainActor
    func testFailedOverviewReloadRetainsSnapshotAndCanRetry() async {
        let model = WorkspaceHomeModel(client: client)
        MockURLProtocol.stubJSON(overview(subscriptions: 3))
        await model.load()
        XCTAssertEqual(model.overview?.subscriptions.totalCount, 3)

        MockURLProtocol.stubJSON(["error": "Workspace unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.overview?.subscriptions.totalCount, 3)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(overview(subscriptions: 4))
        await model.load()
        XCTAssertEqual(model.overview?.subscriptions.totalCount, 4)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testSignOutClearsOverviewWithoutPrivateRequest() async {
        let model = WorkspaceHomeModel(client: client)
        MockURLProtocol.stubJSON(overview(subscriptions: 3))
        await model.load()
        client.clearTokens()
        XCTAssertNil(model.overview)
        let requestCount = MockURLProtocol.capturedRequests.count
        await model.load()
        XCTAssertNil(model.overview)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, requestCount)
    }

    @MainActor
    func testAccountReplacementImmediatelyHidesPreviousOverview() async throws {
        let model = WorkspaceHomeModel(client: client)
        MockURLProtocol.stubJSON(overview(subscriptions: 3))
        await model.load()
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertNil(model.overview)

        MockURLProtocol.stubJSON(["error": "Workspace unavailable"], statusCode: 503)
        await model.load()
        XCTAssertNil(model.overview)
    }

    @MainActor
    func testAccountChangeDuringReloadDiscardsOldOverview() async throws {
        let model = WorkspaceHomeModel(client: client)
        MockURLProtocol.stubJSON(overview(subscriptions: 3))
        await model.load()
        let client = self.client!
        let data = try JSONSerialization.data(withJSONObject: overview(subscriptions: 9))
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        await model.load()
        XCTAssertNil(model.overview)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    private func overview(subscriptions: Int) -> [String: Any] {
        [
            "anchor": ["atTime": "2026-10-23T12:00:00+08:00",
                       "dateFrom": "2026-10-23T00:00:00+08:00",
                       "dateTo": "2026-10-30T00:00:00+08:00"],
            "focus": NSNull(), "urgency": [], "upcoming": [],
            "deadlines": ["today": [], "nextThreeDays": [], "allPending": []],
            "subscriptions": ["totalCount": subscriptions, "currentSemesterCount": 0,
                              "currentSemester": NSNull()],
        ]
    }
}

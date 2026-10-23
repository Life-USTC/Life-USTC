import XCTest
@testable import Life_USTC

final class WorkspaceCalendarModelTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "calendar-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://calendar.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testRetryKeepsSamePeriodButNeverShowsPreviousPeriodAfterNavigation() async {
        let model = ServerWorkspaceCalendarModel(client: client)
        MockURLProtocol.stubJSON(calendarPage)
        await model.load()
        XCTAssertEqual(model.events.map(\.id), ["schedule-1"])

        MockURLProtocol.stubJSON(["error": "Calendar unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.events.map(\.id), ["schedule-1"])
        XCTAssertNotNil(model.error)

        model.referenceDate = YoungCalendarDate.advance(model.referenceDate, mode: .week)
        XCTAssertTrue(model.events.isEmpty)
        await model.load()
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(calendarPage)
        await model.load()
        XCTAssertEqual(model.events.count, 1)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testSessionChangesImmediatelyHideCachedEvents() async throws {
        let model = ServerWorkspaceCalendarModel(client: client)
        MockURLProtocol.stubJSON(calendarPage)
        await model.load()
        XCTAssertEqual(model.events.count, 1)

        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
        XCTAssertTrue(model.events.isEmpty)
        await model.load()
        XCTAssertEqual(model.events.count, 1)

        client.clearTokens()
        XCTAssertTrue(model.events.isEmpty)
    }

    @MainActor
    func testSignOutDuringRefreshRemovesCachedEventsAndRejectsLateResponse() async throws {
        let model = ServerWorkspaceCalendarModel(client: client)
        MockURLProtocol.stubJSON(calendarPage)
        await model.load()
        XCTAssertEqual(model.events.count, 1)
        let client = self.client!
        let data = try JSONSerialization.data(withJSONObject: calendarPage)
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        await model.load()
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        let requestCount = MockURLProtocol.capturedRequests.count
        await model.load()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, requestCount)
    }

    private var calendarPage: [String: Any] {
        [
            "data": [["id": "schedule-1", "type": "schedule", "title": "Calculus",
                      "at": "2026-10-23T08:15:00+08:00", "endsAt": "2026-10-23T09:45:00+08:00",
                      "url": "/catalog/sections/42", "target": ["kind": "section", "id": "42"]]],
            "pagination": ["page": 1, "pageSize": 100, "total": 1, "totalPages": 1],
        ]
    }
}

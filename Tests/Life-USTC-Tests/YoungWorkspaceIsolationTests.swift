import XCTest
@testable import Life_USTC

final class YoungWorkspaceIsolationTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "first-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://young.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testReplacingAuthenticatedAccountHidesEventSubscriptionsAndRejectsOldUnsubscribe() async throws {
        let model = YoungEventSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(page([["youngId": "previous-event", "createdAt": timestamp,
                                       "remindSignup": true, "remindDeadline": false, "remindStart": true,
                                       "event": event]]))
        await model.load()
        let old = try XCTUnwrap(model.subscriptions.first)
        XCTAssertEqual(old.youngId, "previous-event")
        try replaceAccount()
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertTrue(model.subscriptions.isEmpty)
        let before = MockURLProtocol.capturedRequests.count
        MockURLProtocol.stubJSON(["youngId": old.youngId, "subscribed": false,
                                  "remindSignup": false, "remindDeadline": false, "remindStart": false])
        await model.remove(old)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
    }

    @MainActor
    func testReplacingAuthenticatedAccountHidesOrganizerSubscriptionsAndRejectsOldUnfollow() async throws {
        let model = YoungOrganizerSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(page([["organizerId": "previous-organizer", "createdAt": timestamp,
                                       "organizer": ["id": "previous-organizer", "name": "Previous organizer"]]]))
        await model.load()
        let old = try XCTUnwrap(model.subscriptions.first)
        XCTAssertEqual(old.organizerId, "previous-organizer")
        try replaceAccount()
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertTrue(model.subscriptions.isEmpty)
        let before = MockURLProtocol.capturedRequests.count
        MockURLProtocol.stubJSON(["organizerId": old.organizerId, "subscribed": false])
        await model.remove(old)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
    }

    @MainActor
    func testReplacingAuthenticatedAccountHidesNotificationsAndRejectsOldReadRequest() async throws {
        let model = YoungNotificationsModel(client: client)
        MockURLProtocol.stubJSON(page([["id": "previous-notification", "youngId": "previous-event",
                                       "kind": "event_start", "title": "Previous reminder", "body": "Private reminder",
                                       "createdAt": timestamp, "readAt": NSNull()]]))
        await model.load()
        let old = try XCTUnwrap(model.notifications.first)
        XCTAssertFalse(old.isRead)
        try replaceAccount()
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertTrue(model.notifications.isEmpty)
        let before = MockURLProtocol.capturedRequests.count
        MockURLProtocol.stubJSON(["error": "Notification not found"], statusCode: 404)
        await model.markRead(old)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        XCTAssertNil(model.error)
    }

    private var timestamp: String { "2026-10-23T02:03:04Z" }

    private var event: [String: Any] {
        ["youngId": "previous-event", "name": "Previous activity", "isActive": true,
         "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
         "signupDepartmentIds": [], "allowedAttachmentTypes": []]
    }

    private func page(_ data: [[String: Any]]) -> [String: Any] {
        ["data": data, "pagination": ["page": 1, "pageSize": 100, "total": data.count, "totalPages": 1]]
    }

    private func replaceAccount() throws {
        try client.acceptAuthorization(OAuthTokenResponse(
            accessToken: "replacement-owner", tokenType: "Bearer", expiresIn: nil,
            refreshToken: nil, scope: nil
        ), expectedRevision: client.sessionRevision)
    }
}

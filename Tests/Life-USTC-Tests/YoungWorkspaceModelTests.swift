import XCTest
@testable import Life_USTC

final class YoungWorkspaceModelTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2026-10-23T02:03:04Z"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "young-owner"
        client = ServerClient(configuration: .init(baseURL: URL(string: "https://young.example")!,
                                                   session: MockURLProtocol.mockSession(), tokenStore: tokens))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testFailedUnsubscribeRetainsRowAndRetriesTheSameRemoval() async throws {
        let model = YoungEventSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(page([subscription]))
        await model.load()
        let original = try XCTUnwrap(model.subscriptions.first)
        MockURLProtocol.stubJSON(["error": "Insufficient scope"], statusCode: 403)
        await model.remove(original)
        XCTAssertEqual(model.subscriptions.map(\.id), ["event"])
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.mutatingID)
        MockURLProtocol.stubJSON(["youngId": "event", "subscribed": false,
                                  "remindSignup": false, "remindDeadline": false, "remindStart": false])
        let changed = expectation(forNotification: .serverSubscriptionsDidChange, object: nil)
        await model.retry()
        await fulfillment(of: [changed], timeout: 1)
        XCTAssertTrue(model.subscriptions.isEmpty)
        XCTAssertNil(model.error)
        let writes = MockURLProtocol.capturedRequests.filter { $0.httpMethod == "PUT" }
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes.map { $0.url?.path }, Array(repeating: "/api/workspace/young-event-subscriptions/event", count: 2))
        let firstBody = try body(writes[0])
        let retryBody = try body(writes[1])
        XCTAssertEqual(firstBody as NSDictionary, retryBody as NSDictionary)
        XCTAssertEqual(retryBody["subscribed"] as? Bool, false)
    }

    @MainActor
    func testFailedUnfollowRetainsOrganizerAndRetriesTheOriginalAction() async throws {
        let model = YoungOrganizerSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(page([["organizerId": "organizer", "createdAt": timestamp,
                                       "organizer": ["id": "organizer", "name": "Organizer"]]]))
        await model.load()
        let original = try XCTUnwrap(model.subscriptions.first)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.remove(original)
        XCTAssertEqual(model.subscriptions.map(\.id), ["organizer"])
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(["organizerId": "organizer", "subscribed": false])
        await model.retry()
        XCTAssertTrue(model.subscriptions.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.map(\.httpMethod), ["GET", "PUT", "PUT"])
    }

    @MainActor
    func testSubscriptionRefreshFailuresPreservePreviouslyLoadedRows() async throws {
        let model = YoungEventSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(page([subscription]))
        await model.load()
        XCTAssertEqual(model.subscriptions.count, 1)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.subscriptions.map(\.id), ["event"])
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(page([]))
        await model.retry()
        XCTAssertTrue(model.subscriptions.isEmpty)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testUnreadFilterIsSentOnEveryPageAndChangingItHidesThePreviousFilter() async throws {
        let model = YoungNotificationsModel(client: client)
        MockURLProtocol.stubJSON(page([notification(readAt: timestamp)]))
        await model.load()
        XCTAssertTrue(try XCTUnwrap(model.notifications.first).isRead)
        model.unreadOnly = true
        XCTAssertTrue(model.notifications.isEmpty)
        MockURLProtocol.requestHandler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(query.first(where: { $0.name == "unread" })?.value, "true")
            let page = Int(query.first(where: { $0.name == "page" })!.value!)!
            var item = self.notification()
            item["id"] = "unread-\(page)"
            return try self.response(request, self.page([item], page: page, totalPages: 2))
        }
        await model.load()
        XCTAssertEqual(model.notifications.map(\.id), ["unread-1", "unread-2"])
        XCTAssertTrue(model.notifications.allSatisfy { !$0.isRead })
        XCTAssertNil(model.error)
    }

    @MainActor
    func testMarkReadReloadsTheCanonicalTimestampInsteadOfCreatingLocalTime() async throws {
        let model = YoungNotificationsModel(client: client)
        MockURLProtocol.stubJSON(page([notification()]))
        await model.load()
        let original = try XCTUnwrap(model.notifications.first)
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "POST"
                ? try self.response(request, ["id": "notification", "success": true])
                : try self.response(request, self.page([self.notification(readAt: self.timestamp)]))
        }
        await model.markRead(original)
        XCTAssertEqual(model.notifications.first?.readAt, ISO8601DateFormatter().date(from: timestamp))
        XCTAssertNil(model.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.map(\.httpMethod), ["GET", "POST", "GET"])
    }

    @MainActor
    func testConfirmedReadWithFailedReloadRetainsSnapshotAndRetriesOnlyTheListRequest() async throws {
        let model = YoungNotificationsModel(client: client)
        MockURLProtocol.stubJSON(page([notification()]))
        await model.load()
        let original = try XCTUnwrap(model.notifications.first)
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "POST"
                ? try self.response(request, ["id": "notification", "success": true])
                : try self.response(request, ["error": "Unavailable"], status: 503)
        }
        await model.markRead(original)
        XCTAssertEqual(model.notifications.map(\.id), ["notification"])
        XCTAssertNil(model.notifications.first?.readAt)
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(page([notification(readAt: timestamp)]))
        await model.retry()
        XCTAssertEqual(model.notifications.first?.readAt, ISO8601DateFormatter().date(from: timestamp))
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "POST" }.count, 1)
    }

    @MainActor
    func testFailedReadKeepsTheUnreadReminderAndRetriesItsWrite() async throws {
        let model = YoungNotificationsModel(client: client)
        MockURLProtocol.stubJSON(page([notification()]))
        await model.load()
        let original = try XCTUnwrap(model.notifications.first)
        MockURLProtocol.stubJSON(["error": "Notification not found"], statusCode: 404)
        await model.markRead(original)
        XCTAssertFalse(try XCTUnwrap(model.notifications.first).isRead)
        XCTAssertNotNil(model.error)
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "POST"
                ? try self.response(request, ["id": "notification", "success": true])
                : try self.response(request, self.page([self.notification(readAt: self.timestamp)]))
        }
        await model.retry()
        XCTAssertTrue(try XCTUnwrap(model.notifications.first).isRead)
        XCTAssertNil(model.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.map(\.httpMethod), ["GET", "POST", "POST", "GET"])
    }

    @MainActor
    func testReadReminderDisappearsFromCanonicalUnreadResults() async throws {
        let model = YoungNotificationsModel(client: client)
        model.unreadOnly = true
        MockURLProtocol.stubJSON(page([notification()]))
        await model.load()
        let original = try XCTUnwrap(model.notifications.first)
        MockURLProtocol.requestHandler = { request in
            request.httpMethod == "POST"
                ? try self.response(request, ["id": "notification", "success": true])
                : try self.response(request, self.page([]))
        }
        await model.markRead(original)
        XCTAssertTrue(model.notifications.isEmpty)
        XCTAssertNil(model.error)
    }

    private var subscription: [String: Any] {
        ["youngId": "event", "createdAt": timestamp, "remindSignup": true, "remindDeadline": false, "remindStart": true,
         "event": ["youngId": "event", "name": "Activity", "isActive": true,
                   "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
                   "signupDepartmentIds": [], "allowedAttachmentTypes": []]]
    }

    private func notification(readAt: String? = nil) -> [String: Any] {
        ["id": "notification", "youngId": "event", "kind": "event_start", "title": "Activity",
         "body": "Reminder", "createdAt": timestamp, "readAt": readAt as Any? ?? NSNull()]
    }

    private func page(_ data: [[String: Any]], page: Int = 1, totalPages: Int = 1) -> [String: Any] {
        ["data": data, "pagination": ["page": page, "pageSize": 100, "total": data.count * totalPages, "totalPages": totalPages]]
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
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

    private func response(_ request: URLRequest, _ object: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: object))
    }
}

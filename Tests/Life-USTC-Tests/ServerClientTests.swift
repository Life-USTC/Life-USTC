//
//  ServerClientTests.swift
//  Life-USTC-Tests
//
//  Tests for the Server SDK: request building, response parsing,
//  token management, and error handling.
//

import XCTest
@testable import Life_USTC

final class ServerClientTests: XCTestCase {
    var client: ServerClient!
    var tokenStore: MockTokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        tokenStore = MockTokenStore()

        let config = ServerClientConfiguration(
            baseURL: URL(string: "https://test.example.com")!,
            session: MockURLProtocol.mockSession(),
            tokenStore: tokenStore
        )
        client = ServerClient(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        tokenStore = nil
        super.tearDown()
    }

    // MARK: - Request Building

    func testEndpointBuildURLRequest_me() {
        let request = ServerEndpoint.me.buildURLRequest(
            baseURL: URL(string: "https://test.example.com")!
        )
        XCTAssertEqual(request.url?.path, "/api/me")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testEndpointBuildURLRequest_listTodos() {
        let request = ServerEndpoint.listTodos.buildURLRequest(
            baseURL: URL(string: "https://test.example.com")!
        )
        XCTAssertEqual(request.url?.path, "/api/todos")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testEndpointBuildURLRequest_busScheduleWithQuery() {
        let request = ServerEndpoint.busSchedule(
            originCampusId: 1, destinationCampusId: 2,
            dayType: "weekday", limit: 10
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.path, "/api/bus")
        XCTAssertNotNil(components.queryItems)

        let queryDict = Dictionary(
            uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) }
        )
        XCTAssertEqual(queryDict["originCampusId"], "1")
        XCTAssertEqual(queryDict["destinationCampusId"], "2")
        XCTAssertEqual(queryDict["dayType"], "weekday")
        XCTAssertEqual(queryDict["limit"], "10")
    }

    func testEndpointBuildURLRequest_youngEventUsesYoungIdAndPublicPath() {
        let request = ServerEndpoint.getYoungEvent(youngId: "event/中文")
            .buildURLRequest(baseURL: URL(string: "https://test.example.com")!)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(
            components.percentEncodedPath,
            "/api/catalog/young-events/event%2F%E4%B8%AD%E6%96%87"
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testEndpointBuildURLRequest_youngCalendarUsesShanghaiRangeAndPagination() {
        let request = ServerEndpoint.listYoungEvents(
            dateUnknown: nil,
            active: nil,
            category: nil,
            search: nil,
            organizerId: nil,
            dateFrom: "2026-09-14",
            dateTo: "2026-09-20",
            timeBasis: .activity,
            page: 2,
            pageSize: 100
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })
        XCTAssertEqual(components.path, "/api/catalog/young-events")
        XCTAssertEqual(query["dateFrom"], "2026-09-14")
        XCTAssertEqual(query["dateTo"], "2026-09-20")
        XCTAssertEqual(query["timeBasis"], "activity")
        XCTAssertEqual(query["page"], "2")
        XCTAssertEqual(query["pageSize"], "100")
    }

    func testEndpointBuildURLRequest_youngUnknownDateFilter() {
        let request = ServerEndpoint.listYoungEvents(
            dateUnknown: true,
            active: nil,
            category: nil,
            search: nil,
            organizerId: "org-42",
            dateFrom: nil,
            dateTo: nil,
            timeBasis: .registration,
            page: 1,
            pageSize: 100
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })
        XCTAssertEqual(query["dateUnknown"], "true")
        XCTAssertEqual(query["organizerId"], "org-42")
        XCTAssertEqual(query["timeBasis"], "registration")
        XCTAssertNil(query["dateFrom"])
        XCTAssertNil(query["dateTo"])
    }

    func testEndpointBuildURLRequest_youngCommentUsesYoungId() {
        let request = ServerEndpoint.listComments(
            targetType: "young-event",
            targetId: nil,
            youngId: "young-42",
            sectionId: nil,
            teacherId: nil,
            page: 1,
            pageSize: 100
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })
        XCTAssertEqual(components.path, "/api/community/comments")
        XCTAssertEqual(query["targetType"], "young-event")
        XCTAssertEqual(query["youngId"], "young-42")
    }

    func testEndpointBuildURLRequest_commentMutationsUseCommentPathAndMethods() {
        let update = ServerEndpoint.updateComment(
            id: "comment/中文",
            UpdateCommentRequest(body: "Updated", visibility: "public", isAnonymous: false)
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)
        XCTAssertEqual(update.httpMethod, "PATCH")
        XCTAssertEqual(
            URLComponents(url: update.url!, resolvingAgainstBaseURL: false)?.percentEncodedPath,
            "/api/community/comments/comment%2F%E4%B8%AD%E6%96%87"
        )

        let delete = ServerEndpoint.deleteComment(id: "comment-42")
            .buildURLRequest(baseURL: URL(string: "https://test.example.com")!)
        XCTAssertEqual(delete.httpMethod, "DELETE")
        XCTAssertEqual(delete.url?.path, "/api/community/comments/comment-42")
    }

    func testUpdateCommentRequestOmitsUnsetOptionalFields() throws {
        let data = try JSONEncoder().encode(UpdateCommentRequest(body: "Updated"))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["body"] as? String, "Updated")
        XCTAssertNil(object["visibility"])
        XCTAssertNil(object["isAnonymous"])
        XCTAssertNil(object["attachmentIds"])
    }

    func testEndpointBuildURLRequest_commentRepliesUsesOpaqueCursor() {
        let request = ServerEndpoint.listCommentReplies(
            id: "comment/中文",
            cursor: "cursor+/=",
            pageSize: 20
        ).buildURLRequest(baseURL: URL(string: "https://test.example.com")!)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            components.percentEncodedPath,
            "/api/community/comments/comment%2F%E4%B8%AD%E6%96%87/replies"
        )
        XCTAssertEqual(query["cursor"], "cursor+/=")
        XCTAssertEqual(query["pageSize"], "20")
    }

    // MARK: - Response Decoding

    func testDecodeServerUser() async throws {
        let json: [String: Any] = [
            "id": "user-123",
            "email": "test@example.com",
            "name": "Test User",
            "image": NSNull(),
            "username": "testuser",
            "isAdmin": false,
        ]

        MockURLProtocol.stubJSON(json)
        tokenStore.accessToken = "fake-token"

        let user: ServerUser = try await client.request(.me)
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertFalse(user.isAdmin)
    }

    func testDecodeTodoList() async throws {
        let json: [String: Any] = [
            "todos": [
                [
                    "id": "todo-1",
                    "userId": "user-1",
                    "title": "Buy milk",
                    "content": NSNull(),
                    "priority": "medium",
                    "completed": false,
                    "dueAt": NSNull(),
                    "createdAt": "2026-01-01T00:00:00.000Z",
                    "updatedAt": "2026-01-01T00:00:00.000Z",
                ],
            ]
        ]

        MockURLProtocol.stubJSON(json)
        tokenStore.accessToken = "fake-token"

        let response: ServerTodoListResponse = try await client.request(.listTodos)
        XCTAssertEqual(response.todos.count, 1)
        XCTAssertEqual(response.todos[0].title, "Buy milk")
        XCTAssertEqual(response.todos[0].priority, .medium)
        XCTAssertFalse(response.todos[0].completed)
    }

    func testDecodeYoungEventDetail() async throws {
        MockURLProtocol.stubJSON([
            "youngId": "young-42",
            "name": "Campus Volunteer Day",
            "category": NSNull(),
            "department": "Student Affairs",
            "organizer": "Volunteer Center",
            "organizerId": "org-1",
            "status": "Open",
            "requiresSignup": true,
            "requiresSignupInfo": true,
            "isOnline": true,
            "onlineMeetingInfo": "800-414-186",
            "externalSponsor": "Partner",
            "allowedAttachmentTypes": ["pdf"],
            "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [], "signupDepartmentIds": [],
            "location": "East Campus",
            "imageUrl": NSNull(),
            "hours": 2.5,
            "capacity": 100,
            "appliedCount": 20,
            "startAt": "2026-09-20T09:00:00+08:00",
            "endAt": "2026-09-20T11:00:00+08:00",
            "applyStartAt": "2026-09-01T00:00:00+08:00",
            "applyEndAt": "2026-09-19T23:59:59+08:00",
            "isActive": true,
            "sourceMissing": false,
            "lastSeenAt": "2026-09-15T00:00:00+08:00",
            "createdAt": NSNull(),
            "rawJson": [:],
        ])

        let event: ServerYoungEvent = try await client.request(.getYoungEvent(youngId: "young-42"))
        XCTAssertEqual(event.onlineMeetingInfo, "800-414-186")
        XCTAssertEqual(event.allowedAttachmentTypes, ["pdf"])
        XCTAssertEqual(event.requiresSignupInfo, true)
        XCTAssertEqual(event.youngId, "young-42")
        XCTAssertEqual(event.organizerId, "org-1")
        XCTAssertEqual(event.hours, 2.5)
        XCTAssertTrue(event.isActive)
    }

    func testFetchYoungEventsFollowsAllPages() async throws {
        var requestedPages: [String] = []
        MockURLProtocol.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let page = components.queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
            requestedPages.append(page)
            let name = page == "1" ? "First" : "Second"
            let body: [String: Any] = [
                "data": [[
                    "youngId": "young-\(page)",
                    "name": name,
                    "category": NSNull(),
                    "department": NSNull(),
                    "organizer": NSNull(),
                    "organizerId": NSNull(),
                    "status": NSNull(),
                    "requiresSignup": NSNull(),
                    "allowedAttachmentTypes": [], "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [], "signupDepartmentIds": [],
                    "location": NSNull(),
                    "imageUrl": NSNull(),
                    "hours": NSNull(),
                    "capacity": NSNull(),
                    "appliedCount": NSNull(),
                    "startAt": NSNull(),
                    "endAt": NSNull(),
                    "applyStartAt": NSNull(),
                    "applyEndAt": NSNull(),
                    "isActive": false,
                    "sourceMissing": false,
                    "lastSeenAt": NSNull(),
                    "createdAt": NSNull(),
                ]],
                "pagination": ["page": Int(page)!, "pageSize": 1, "total": 2, "totalPages": 2],
                "unknownDateCount": 3,
                "source": ["status": "fresh", "lastSyncedAt": "2026-09-15T00:00:00Z"],
            ]
            let data = try JSONSerialization.data(withJSONObject: body)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let page = try await client.fetchYoungEventsPage()
        XCTAssertEqual(page.data.map(\.youngId), ["young-1", "young-2"])
        XCTAssertEqual(page.unknownDateCount, 3)
        XCTAssertEqual(page.source.status, "fresh")
        XCTAssertEqual(requestedPages, ["1", "2"])
    }

    func testDecodeYoungEventCommentsAndTarget() async throws {
        MockURLProtocol.stubJSON([
            "data": [[
                "id": "comment-1",
                "body": "Looking forward to it",
                "renderedBody": "Looking forward to it",
                "visibility": "public",
                "status": "visible",
                "author": NSNull(),
                "authorHidden": false,
                "isAnonymous": true,
                "isAuthor": false,
                "createdAt": "2026-09-15T00:00:00Z",
                "updatedAt": "2026-09-15T00:00:00Z",
                "parentId": NSNull(),
                "rootId": NSNull(),
                "replies": [],
                "repliesNextCursor": NSNull(),
                "attachments": [],
                "reactions": [[
                    "type": "heart",
                    "count": 2,
                    "viewerHasReacted": true,
                ]],
                "canReact": true,
                "canReply": true,
                "canEdit": false,
                "canDelete": false,
                "canModerate": false,
            ]],
            "pagination": ["page": 1, "pageSize": 100, "total": 1, "totalPages": 1],
            "meta": [
                "hiddenCount": 0,
                "viewer": [
                    "userId": NSNull(), "name": NSNull(), "image": NSNull(),
                    "isAdmin": false, "isAuthenticated": false, "isSuspended": false,
                    "suspensionReason": NSNull(), "suspensionExpiresAt": NSNull(),
                ],
                "target": [
                    "type": "young-event", "targetId": NSNull(),
                    "youngId": "young-42", "youngEventId": NSNull(),
                    "youngEventName": "Campus Volunteer Day",
                ],
            ],
        ])

        let response: ServerCommentListResponse = try await client.request(
            .listComments(
                targetType: "young-event",
                targetId: nil,
                youngId: "young-42",
                sectionId: nil,
                teacherId: nil,
                page: 1,
                pageSize: 100
            )
        )
        XCTAssertEqual(response.comments.count, 1)
        XCTAssertEqual(response.meta.target.youngId, "young-42")
        XCTAssertTrue(response.comments[0].reactions[0].hasReacted)
    }

    // MARK: - Authentication

    func testRequestIncludesAuthHeader() async throws {
        tokenStore.accessToken = "my-jwt-token"
        MockURLProtocol.stubJSON(["id": "u1", "email": "a@b.com", "name": "A", "isAdmin": false])

        let _: ServerUser = try await client.request(.me)

        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        let authHeader = MockURLProtocol.capturedRequests[0].value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer my-jwt-token")
    }

    func testUnauthenticatedRequestOmitsAuthHeader() async throws {
        tokenStore.accessToken = ""
        MockURLProtocol.stubJSON(["campus": [], "routes": [], "trips": []])

        let _: ServerBusResponse = try await client.request(
            .busSchedule(originCampusId: nil, destinationCampusId: nil, dayType: nil, limit: nil)
        )

        let authHeader = MockURLProtocol.capturedRequests[0].value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(authHeader)
    }

    // MARK: - Error Handling

    func testNotFoundThrows() async {
        MockURLProtocol.stubData(Data(), statusCode: 404)
        tokenStore.accessToken = "token"

        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("Expected ServerError.notFound")
        } catch {
            guard case ServerError.notFound = error else {
                XCTFail("Expected ServerError.notFound, got \(error)")
                return
            }
        }
    }

    func testUnauthorizedWithNoRefreshTokenThrows() async {
        MockURLProtocol.stubData(Data(), statusCode: 401)
        tokenStore.accessToken = "expired"
        tokenStore.refreshToken = ""

        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("Expected ServerError.notAuthenticated")
        } catch {
            guard case ServerError.notAuthenticated = error else {
                XCTFail("Expected ServerError.notAuthenticated, got \(error)")
                return
            }
        }
    }

    func testBadRequestReturnsMessage() async {
        let errorJSON = try! JSONSerialization.data(
            withJSONObject: ["error": "Invalid input"]
        )
        MockURLProtocol.stubData(errorJSON, statusCode: 400)
        tokenStore.accessToken = "token"

        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("Expected ServerError.badRequest")
        } catch {
            guard case ServerError.badRequest(let msg) = error else {
                XCTFail("Expected ServerError.badRequest, got \(error)")
                return
            }
            XCTAssertEqual(msg, "Invalid input")
        }
    }

    // MARK: - Token Store

    func testClearTokens() {
        tokenStore.accessToken = "abc"
        tokenStore.refreshToken = "xyz"
        client.clearTokens()
        XCTAssertTrue(tokenStore.accessToken.isEmpty)
        XCTAssertTrue(tokenStore.refreshToken.isEmpty)
    }

    func testIsAuthenticated() {
        tokenStore.accessToken = ""
        XCTAssertFalse(client.isAuthenticated)
        tokenStore.accessToken = "token"
        XCTAssertTrue(client.isAuthenticated)
    }

    // MARK: - Token Refresh

    func testTokenRefreshOn401() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1

            if request.url?.path == "/api/me" && requestCount == 1 {
                // First call: 401
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 401,
                    httpVersion: nil, headerFields: nil
                )!
                return (response, Data())
            } else if request.url?.path.contains("oauth2/token") == true {
                // Token refresh: success
                let tokenJSON = """
                {"access_token":"new-token","token_type":"Bearer","expires_in":3600,"refresh_token":"new-refresh"}
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 200,
                    httpVersion: nil, headerFields: nil
                )!
                return (response, tokenJSON)
            } else {
                // Retry /api/me: success
                let userJSON = """
                {"id":"u1","email":"a@b.com","name":"A","isAdmin":false}
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 200,
                    httpVersion: nil, headerFields: nil
                )!
                return (response, userJSON)
            }
        }

        tokenStore.accessToken = "expired-token"
        tokenStore.refreshToken = "valid-refresh"

        let user: ServerUser = try await client.request(.me)
        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(tokenStore.accessToken, "new-token")
        XCTAssertEqual(tokenStore.refreshToken, "new-refresh")
    }

    // MARK: - Date Decoding

    func testDateDecodingWithFractionalSeconds() throws {
        let json = """
        {"id":"t1","userId":"u1","title":"Test","priority":"low","completed":false,"createdAt":"2026-01-15T10:30:00.123Z","updatedAt":"2026-01-15T10:30:00.123Z"}
        """.data(using: .utf8)!

        let todo = try client.decoder.decode(ServerTodo.self, from: json)
        XCTAssertEqual(todo.id, "t1")

        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: todo.createdAt)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
    }

    func testDateDecodingWithoutFractionalSeconds() throws {
        let json = """
        {"id":"t2","userId":"u1","title":"Test2","priority":"high","completed":true,"createdAt":"2026-06-01T08:00:00Z","updatedAt":"2026-06-01T08:00:00Z"}
        """.data(using: .utf8)!

        let todo = try client.decoder.decode(ServerTodo.self, from: json)
        XCTAssertEqual(todo.id, "t2")
        XCTAssertTrue(todo.completed)
    }

    func testYoungCalendarDateUsesShanghaiMondayWeek() {
        var calendar = YoungCalendarDate.calendar
        calendar.timeZone = YoungCalendarDate.shanghai
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let monday = YoungCalendarDate.weekStart(sunday)
        XCTAssertEqual(YoungCalendarDate.dateString(monday), "2026-09-14")

        let range = YoungCalendarDate.range(for: .week, date: sunday)
        XCTAssertEqual(range.from, "2026-09-14")
        XCTAssertEqual(range.to, "2026-09-20")
    }
}

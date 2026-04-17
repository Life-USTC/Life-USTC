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
}

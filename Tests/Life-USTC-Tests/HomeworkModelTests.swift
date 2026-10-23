import XCTest
@testable import Life_USTC

final class HomeworkModelTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2035-09-15T10:30:25+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "homework-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://homework.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testFailedListReloadKeepsSnapshotUntilRetrySucceeds() async {
        let model = ServerHomeworkListModel(client: client)
        MockURLProtocol.stubJSON(page([homework("first")]))
        await model.load()

        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.homeworks.map(\.id), ["first"])
        XCTAssertNotNil(model.loadError)
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(page([homework("second")]))
        await model.load()
        XCTAssertEqual(model.homeworks.map(\.id), ["second"])
        XCTAssertNil(model.loadError)
    }

    @MainActor
    func testStatusBucketsRetainOverdueStudentWorkAndForbidTAActions() async throws {
        let model = ServerHomeworkListModel(client: client)
        MockURLProtocol.stubJSON(page([
            homework("student-overdue", dueAt: timestamp),
            homework("ta-deadline", completionRequired: false, dueAt: timestamp),
            homework("ta-undated", completionRequired: false),
            homework("completed", completed: true)
        ]))
        await model.load()
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: timestamp))
        XCTAssertEqual(model.visibleHomeworks(at: now).map(\.id), ["student-overdue", "ta-undated"])
        model.status = .completed
        XCTAssertEqual(model.visibleHomeworks(at: now).map(\.id), ["ta-deadline", "completed"])
        model.status = .all
        XCTAssertEqual(model.visibleHomeworks(at: now).count, 4)

        let ta = try XCTUnwrap(model.homeworks.first { $0.id == "ta-undated" })
        let before = MockURLProtocol.capturedRequests.count
        let updated = await model.toggleCompletion(ta)
        XCTAssertFalse(updated)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        XCTAssertNil(model.mutationError)
    }

    @MainActor
    func testLogoutImmediatelyHidesListAndDetailAndRejectsStaleActions() async throws {
        let list = ServerHomeworkListModel(client: client)
        let detail = ServerHomeworkDetailModel(homeworkID: "private", client: client)
        MockURLProtocol.stubJSON(page([homework("private")]))
        await list.load()
        let previous = try XCTUnwrap(list.homeworks.first)
        MockURLProtocol.stubJSON(["homework": homework("private")])
        await detail.load()
        XCTAssertNotNil(detail.homework)

        client.clearTokens()
        XCTAssertTrue(list.homeworks.isEmpty)
        XCTAssertNil(detail.homework)
        let before = MockURLProtocol.capturedRequests.count
        let listUpdated = await list.toggleCompletion(previous)
        let detailUpdated = await detail.toggleCompletion()
        XCTAssertFalse(listUpdated)
        XCTAssertFalse(detailUpdated)
        await list.load()
        MockURLProtocol.stubJSON(["homework": homework("private")])
        await detail.load()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before + 1)
        XCTAssertNotNil(detail.homework, "The current anonymous session can read public homework after discarding the old snapshot")
        XCTAssertNil(detail.homework?.completion)
        XCTAssertNil(MockURLProtocol.capturedRequests.last?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(list.isLoading)
        XCTAssertFalse(detail.isLoading)
        XCTAssertNil(list.loadError)
        XCTAssertNil(detail.loadError)
    }

    @MainActor
    func testFailedCompletionRetainsSnapshotAndRetriesSameIntentAfterRefresh() async throws {
        let model = ServerHomeworkListModel(client: client)
        MockURLProtocol.stubJSON(page([homework("pending")]))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Write unavailable"], statusCode: 503)
        let updated = await model.toggleCompletion(try XCTUnwrap(model.homeworks.first))
        XCTAssertFalse(updated)
        XCTAssertNil(model.homeworks.first?.completion)
        XCTAssertNotNil(model.mutationError)
        XCTAssertTrue(model.canRetryMutation)
        XCTAssertNil(model.mutatingID)

        // Another client may finish the item while the failed intent remains retryable.
        MockURLProtocol.stubJSON(page([homework("pending", completed: true)]))
        await model.load()
        XCTAssertNotNil(model.homeworks.first?.completion)
        MockURLProtocol.stubJSON(["completed": true, "completedAt": timestamp])
        let retried = await model.retryMutation()
        XCTAssertTrue(retried)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["completed"] as? Bool, true)
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.canRetryMutation)
    }

    @MainActor
    func testSuccessfulCompletionWaitsForCanonicalReadBeforeChangingSnapshot() async throws {
        let model = ServerHomeworkListModel(client: client)
        MockURLProtocol.stubJSON(page([homework("pending")]))
        await model.load()
        MockURLProtocol.stubJSON(["completed": true, "completedAt": timestamp])
        let updated = await model.toggleCompletion(try XCTUnwrap(model.homeworks.first))
        XCTAssertTrue(updated)
        XCTAssertNil(model.homeworks.first?.completion)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "GET" }.count, 1)

        // The view's workspace-change listener performs this canonical reload.
        MockURLProtocol.stubJSON(page([homework("pending", completed: true)]))
        await model.load()
        XCTAssertEqual(model.homeworks.first?.completion?.completedAt,
                       ISO8601DateFormatter().date(from: timestamp))
    }

    @MainActor
    func testFailedDetailReloadAndReopenPreserveContentUntilCanonicalRetry() async throws {
        let model = ServerHomeworkDetailModel(homeworkID: "complete", client: client)
        MockURLProtocol.stubJSON(["homework": homework("complete", completed: true)])
        await model.load()
        let completedAt = try XCTUnwrap(model.homework?.completion?.completedAt)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.homework?.description?.content, "Assignment details")
        XCTAssertNotNil(model.loadError)

        let updated = await model.toggleCompletion()
        XCTAssertFalse(updated)
        XCTAssertEqual(model.homework?.completion?.completedAt, completedAt)
        XCTAssertNotNil(model.mutationError)
        XCTAssertTrue(model.canRetryMutation)
        XCTAssertFalse(model.isSaving)
        MockURLProtocol.stubJSON(["completed": false, "completedAt": NSNull()])
        let retried = await model.retryMutation()
        XCTAssertTrue(retried)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["completed"] as? Bool, false)
        XCTAssertEqual(model.homework?.completion?.completedAt, completedAt)

        MockURLProtocol.stubJSON(["homework": homework("complete")])
        await model.load()
        XCTAssertNil(model.homework?.completion)
        XCTAssertNil(model.loadError)
        XCTAssertNil(model.mutationError)
    }

    @MainActor
    func testTeachingAssistantDetailCannotSubmitCompletion() async {
        let model = ServerHomeworkDetailModel(homeworkID: "ta", client: client)
        MockURLProtocol.stubJSON(["homework": homework("ta", completionRequired: false)])
        await model.load()
        let before = MockURLProtocol.capturedRequests.count
        let updated = await model.toggleCompletion()
        XCTAssertFalse(updated)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        XCTAssertFalse(model.isSaving)
        XCTAssertFalse(model.canRetryMutation)
    }

    @MainActor
    func testLogoutDuringMutationDiscardsFailureAndRetryIntent() async throws {
        let model = ServerHomeworkListModel(client: client)
        MockURLProtocol.stubJSON(page([homework("private")]))
        await model.load()
        let client = client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 503,
                                    httpVersion: nil, headerFields: nil)!, Data(#"{"error":"Former owner"}"#.utf8))
        }
        let updated = await model.toggleCompletion(try XCTUnwrap(model.homeworks.first))
        XCTAssertFalse(updated)
        XCTAssertTrue(model.homeworks.isEmpty)
        XCTAssertNil(model.mutationError)
        XCTAssertNil(model.mutatingID)
        XCTAssertFalse(model.canRetryMutation)
    }

    @MainActor
    func testLogoutDuringDetailReadDiscardsDataAndLoadingState() async throws {
        let model = ServerHomeworkDetailModel(homeworkID: "private", client: client)
        let client = client!
        let data = try JSONSerialization.data(withJSONObject: ["homework": homework("private")])
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        await model.load()
        XCTAssertNil(model.homework)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testReplacingAccountDuringDetailMutationCannotPublishFormerOwnersSuccess() async throws {
        let model = ServerHomeworkDetailModel(homeworkID: "private", client: client)
        MockURLProtocol.stubJSON(["homework": homework("private")])
        await model.load()
        let client = client!
        let revision = client.sessionRevision
        MockURLProtocol.requestHandler = { request in
            try client.acceptAuthorization(OAuthTokenResponse(
                accessToken: "new-owner", tokenType: "Bearer", expiresIn: nil,
                refreshToken: nil, scope: nil
            ), expectedRevision: revision)
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!,
                    Data(#"{"completed":true,"completedAt":"2035-09-15T10:30:25+08:00"}"#.utf8))
        }
        let updated = await model.toggleCompletion()
        XCTAssertFalse(updated)
        XCTAssertTrue(client.isAuthenticated)
        XCTAssertNil(model.homework)
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.isSaving)
        XCTAssertFalse(model.canRetryMutation)
        let before = MockURLProtocol.capturedRequests.count
        let retried = await model.retryMutation()
        XCTAssertFalse(retried)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
    }

    @MainActor
    func testLateListResponseCannotOverwriteNewerCanonicalSnapshot() async throws {
        let tokens = MockTokenStore()
        tokens.accessToken = "homework-owner"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredHomeworkURLProtocol.self]
        let delayedClient = ServerClient(configuration: .init(
            baseURL: URL(string: "https://homework.example")!,
            session: URLSession(configuration: configuration), tokenStore: tokens
        ))
        let model = ServerHomeworkListModel(client: delayedClient)
        DeferredHomeworkURLProtocol.requests = []
        defer {
            DeferredHomeworkURLProtocol.requests = []
            DeferredHomeworkURLProtocol.onRequest = nil
        }
        let firstStarted = expectation(description: "Initial load started")
        DeferredHomeworkURLProtocol.onRequest = { firstStarted.fulfill() }
        let first = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectation(description: "Canonical reload started")
        DeferredHomeworkURLProtocol.onRequest = { secondStarted.fulfill() }
        let second = Task { await model.load() }
        await fulfillment(of: [secondStarted], timeout: 2)

        let secondRequest = try XCTUnwrap(DeferredHomeworkURLProtocol.requests.last)
        try secondRequest.complete(page([homework("new", completed: true)]))
        await second.value
        let firstRequest = try XCTUnwrap(DeferredHomeworkURLProtocol.requests.first)
        try firstRequest.complete(page([homework("old")]))
        await first.value
        XCTAssertEqual(model.homeworks.map(\.id), ["new"])
        XCTAssertNotNil(model.homeworks.first?.completion)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.loadError)
    }

    private func homework(_ id: String, completionRequired: Bool = true,
                          dueAt: String? = nil, completed: Bool = false) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": id, "isMajor": false, "requiresTeam": false,
         "completionRequired": completionRequired, "createdAt": timestamp, "updatedAt": timestamp,
         "submissionDueAt": dueAt as Any? ?? NSNull(),
         "completion": completed ? ["completedAt": timestamp] as Any : NSNull(),
         "description": ["id": "description-\(id)", "content": "Assignment details"]]
    }

    private func page(_ homeworks: [[String: Any]]) -> [String: Any] {
        ["data": homeworks, "pagination": ["page": 1, "pageSize": 50,
                                          "total": homeworks.count, "totalPages": 1]]
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
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class DeferredHomeworkURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredHomeworkURLProtocol] = []
    @MainActor static var onRequest: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task { @MainActor in
            Self.requests.append(self)
            Self.onRequest?()
        }
    }

    override func stopLoading() {}

    @MainActor
    func complete(_ json: [String: Any]) throws {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
}

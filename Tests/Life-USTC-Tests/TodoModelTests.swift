import XCTest
@testable import Life_USTC

final class TodoModelTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2035-09-15T10:30:25.123+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "todo-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://todos.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testFailedReloadKeepsSnapshotAndCountsUntilRetrySucceeds() async {
        let model = ServerTodoListModel(client: client)
        MockURLProtocol.stubJSON(page([todo("first")]))
        await model.load()
        XCTAssertEqual(model.todos.map(\.id), ["first"])
        XCTAssertEqual(model.counts?.incomplete, 1)

        model.query.priority = .high
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.todos.map(\.id), ["first"])
        XCTAssertEqual(model.counts?.incomplete, 1)
        XCTAssertTrue(model.showsPreviousFilterResults)
        XCTAssertNotNil(model.loadError)
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(page([todo("second")]))
        await model.load()
        XCTAssertEqual(model.todos.map(\.id), ["second"])
        XCTAssertFalse(model.showsPreviousFilterResults)
        XCTAssertNil(model.loadError)
    }

    @MainActor
    func testSessionChangeImmediatelyHidesSnapshotAndRejectsOldMutation() async throws {
        let model = ServerTodoListModel(client: client)
        MockURLProtocol.stubJSON(page([todo("private-todo")]))
        await model.load()
        let previousTodo = try XCTUnwrap(model.todos.first)
        client.clearTokens()
        XCTAssertTrue(model.todos.isEmpty)
        XCTAssertNil(model.counts)

        let before = MockURLProtocol.capturedRequests.count
        let updated = await model.toggleCompletion(previousTodo)
        let deleted = await model.delete(previousTodo)
        XCTAssertFalse(updated)
        XCTAssertFalse(deleted)
        await model.load()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.loadError)
    }

    @MainActor
    func testAccountChangeDuringReloadDiscardsFormerOwnersResult() async throws {
        let model = ServerTodoListModel(client: client)
        MockURLProtocol.stubJSON(page([todo("first")]))
        await model.load()
        let client = client!
        let data = try JSONSerialization.data(withJSONObject: page([todo("private-result")]))
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        await model.load()
        XCTAssertTrue(model.todos.isEmpty)
        XCTAssertNil(model.counts)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testLateResponseForPreviousFilterCannotReplaceNewerResults() async throws {
        let tokens = MockTokenStore()
        tokens.accessToken = "todo-owner"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredTodoURLProtocol.self]
        let delayedClient = ServerClient(configuration: .init(
            baseURL: URL(string: "https://todos.example")!,
            session: URLSession(configuration: configuration), tokenStore: tokens
        ))
        let model = ServerTodoListModel(client: delayedClient)
        DeferredTodoURLProtocol.requests = []
        defer {
            DeferredTodoURLProtocol.requests = []
            DeferredTodoURLProtocol.onRequest = nil
        }
        let firstStarted = expectation(description: "Pending filter request started")
        DeferredTodoURLProtocol.onRequest = { firstStarted.fulfill() }
        let first = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)

        let secondStarted = expectation(description: "Completed filter request started")
        DeferredTodoURLProtocol.onRequest = { secondStarted.fulfill() }
        model.query.status = .completed
        let second = Task { await model.load() }
        await fulfillment(of: [secondStarted], timeout: 2)
        XCTAssertEqual(DeferredTodoURLProtocol.requests.count, 2)
        try DeferredTodoURLProtocol.requests[1].complete(page([todo("new-completed", completed: true)]))
        await second.value
        XCTAssertEqual(model.todos.map(\.id), ["new-completed"])

        try DeferredTodoURLProtocol.requests[0].complete(page([todo("old-pending")]))
        await first.value
        XCTAssertEqual(model.todos.map(\.id), ["new-completed"])
        XCTAssertFalse(model.showsPreviousFilterResults)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedCompletionRetainsRowAndRetriesSameIntendedValue() async throws {
        let model = ServerTodoListModel(client: client)
        MockURLProtocol.stubJSON(page([todo("pending")]))
        await model.load()
        let pending = try XCTUnwrap(model.todos.first)
        MockURLProtocol.stubJSON(["error": "Write unavailable"], statusCode: 503)
        let updated = await model.toggleCompletion(pending)
        XCTAssertFalse(updated)
        XCTAssertEqual(model.todos.first?.completed, false)
        XCTAssertNotNil(model.mutationError)
        XCTAssertTrue(model.canRetryMutation)
        XCTAssertTrue(model.mutatingIDs.isEmpty)
        var body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["completed"] as? Bool, true)

        MockURLProtocol.stubJSON(["success": true, "todo": todo("pending", completed: true)])
        let retried = await model.retryMutation()
        XCTAssertTrue(retried)
        body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["completed"] as? Bool, true)
        XCTAssertNil(model.mutationError)
        XCTAssertFalse(model.canRetryMutation)
        // The notification listener reloads the canonical list after the write.
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.httpMethod == "GET" }.count, 1)
    }

    @MainActor
    func testFailedDeletePreservesTodoAndConfirmedIntentCanBeRetried() async throws {
        let model = ServerTodoListModel(client: client)
        MockURLProtocol.stubJSON(page([todo("keep-until-confirmed")]))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Forbidden"], statusCode: 403)
        let deleted = await model.delete(try XCTUnwrap(model.todos.first))
        XCTAssertFalse(deleted)
        XCTAssertEqual(model.todos.map(\.id), ["keep-until-confirmed"])
        XCTAssertNotNil(model.mutationError)
        XCTAssertTrue(model.canRetryMutation)

        model.query.status = .completed
        MockURLProtocol.stubJSON(page([]))
        await model.load()
        XCTAssertTrue(model.todos.isEmpty)
        XCTAssertTrue(model.canRetryMutation)
        MockURLProtocol.stubJSON(["success": true])
        let retried = await model.retryMutation()
        XCTAssertTrue(retried)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path,
                       "/api/workspace/todos/keep-until-confirmed")
        XCTAssertNil(model.mutationError)
    }

    @MainActor
    func testInclusiveDateFiltersUseShanghaiDayBoundsAndRejectReversedRange() async {
        let model = ServerTodoListModel(client: client)
        let formatter = ISO8601DateFormatter()
        model.query = ServerTodoListQuery(
            status: .all, priority: .high,
            dueFrom: formatter.date(from: "2035-09-14T17:30:00Z"),
            dueThrough: formatter.date(from: "2035-09-16T08:30:00Z")
        )
        let filters = model.query.filters
        XCTAssertNil(filters.completed)
        XCTAssertEqual(filters.priority, .high)
        XCTAssertEqual(filters.dueAfter, formatter.date(from: "2035-09-14T16:00:00Z"))
        XCTAssertEqual(filters.dueBefore, formatter.date(from: "2035-09-16T16:00:00Z"))

        model.query.dueThrough = formatter.date(from: "2035-09-13T08:30:00Z")
        await model.load()
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        XCTAssertNotNil(model.loadError)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedEditPreservesDraftAndOnlySuccessfulRetryCanDismiss() async throws {
        let original = try decodeTodo(todo("edit", content: "Original notes", dueAt: timestamp))
        let model = ServerTodoEditorModel(todo: original, client: client)
        model.title = "Edited title"
        model.content = "Edited notes"
        model.priority = .high
        let dueDate = model.dueDate.addingTimeInterval(3600)
        model.dueDate = dueDate
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        let failed = await model.save()
        XCTAssertFalse(failed)
        XCTAssertFalse(model.hasSaved)
        XCTAssertEqual(model.title, "Edited title")
        XCTAssertEqual(model.content, "Edited notes")
        XCTAssertEqual(model.priority, .high)
        XCTAssertEqual(model.dueDate, dueDate)
        XCTAssertTrue(model.hasDueDate)
        XCTAssertFalse(model.isSaving)
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.canSave)

        MockURLProtocol.stubJSON(["success": true, "todo": todo("edit")])
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertTrue(model.hasSaved)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.canSave)
    }

    @MainActor
    func testTitleOnlyEditOmitsUnchangedContentAndExactDueDate() async throws {
        let original = try decodeTodo(todo("edit", content: "Keep notes", dueAt: timestamp))
        let model = ServerTodoEditorModel(todo: original, client: client)
        XCTAssertFalse(model.hasChanges)
        model.title = "New title"
        MockURLProtocol.stubJSON(["success": true, "todo": todo("edit")])
        let saved = await model.save()
        XCTAssertTrue(saved)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(Set(body.keys), ["title"])
        XCTAssertEqual(body["title"] as? String, "New title")
        XCTAssertEqual(model.dueDate, original.dueAt)
    }

    @MainActor
    func testClearingPreviousContentAndDateSendsExplicitNull() async throws {
        let original = try decodeTodo(todo("edit", content: "Remove notes", dueAt: timestamp))
        let model = ServerTodoEditorModel(todo: original, client: client)
        model.content = " \n "
        model.hasDueDate = false
        MockURLProtocol.stubJSON(["success": true, "todo": todo("edit")])
        let saved = await model.save()
        XCTAssertTrue(saved)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(Set(body.keys), ["content", "dueAt"])
        XCTAssertTrue(body["content"] is NSNull)
        XCTAssertTrue(body["dueAt"] is NSNull)
    }

    @MainActor
    func testUnchangedEditAndFormerSessionDraftNeverWrite() async throws {
        let original = try decodeTodo(todo("edit"))
        let model = ServerTodoEditorModel(todo: original, client: client)
        let unchanged = await model.save()
        XCTAssertFalse(unchanged)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        model.title = "Private draft"
        client.clearTokens()
        let stale = await model.save()
        XCTAssertFalse(stale)
        XCTAssertFalse(model.isCurrentSession)
        XCTAssertEqual(model.title, "Private draft")
        XCTAssertNotNil(model.error)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testSessionChangeDuringSaveDoesNotReportSuccess() async throws {
        let model = ServerTodoEditorModel(client: client)
        model.title = "Draft"
        let client = client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 201,
                                    httpVersion: nil, headerFields: nil)!, Data(#"{"id":"created"}"#.utf8))
        }
        let saved = await model.save()
        XCTAssertFalse(saved)
        XCTAssertFalse(model.hasSaved)
        XCTAssertFalse(model.isSaving)
        XCTAssertEqual(model.title, "Draft")
    }

    @MainActor
    func testValidationUsesTrimmedServerUTF16LimitsAndCreateIsNotRepeated() async throws {
        let model = ServerTodoEditorModel(client: client)
        model.title = " \n\u{FEFF} "
        XCTAssertNotNil(model.validationError)
        model.title = "\u{0085}"
        XCTAssertNil(model.validationError, "ECMAScript does not trim the next-line control character")
        model.title = String(repeating: "😀", count: 101)
        XCTAssertNotNil(model.validationError)
        model.title = " \n" + String(repeating: "😀", count: 100) + " \n"
        XCTAssertNil(model.validationError)
        model.content = String(repeating: "😀", count: 2001)
        XCTAssertNotNil(model.validationError)
        let invalid = await model.save()
        XCTAssertFalse(invalid)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)

        model.content = " Notes \n"
        MockURLProtocol.stubJSON(["id": "created"], statusCode: 201)
        let saved = await model.save()
        let repeated = await model.save()
        XCTAssertTrue(saved)
        XCTAssertFalse(repeated)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        let body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["title"] as? String, String(repeating: "😀", count: 100))
        XCTAssertEqual(body["content"] as? String, "Notes")
        XCTAssertNil(body["dueAt"])
    }

    private func todo(_ id: String, content: String? = nil, dueAt: String? = nil,
                      completed: Bool = false) -> [String: Any] {
        ["id": id, "title": id, "content": content as Any? ?? NSNull(), "priority": "medium",
         "completed": completed, "dueAt": dueAt as Any? ?? NSNull(),
         "createdAt": timestamp, "updatedAt": timestamp]
    }

    private func page(_ todos: [[String: Any]]) -> [String: Any] {
        ["data": todos, "meta": ["counts": ["completed": 0, "incomplete": todos.count, "overdue": 0]],
         "pagination": ["page": 1, "pageSize": 100, "total": todos.count, "totalPages": 1]]
    }

    private func decodeTodo(_ json: [String: Any]) throws -> ServerTodo {
        try client.decoder.decode(ServerTodo.self, from: JSONSerialization.data(withJSONObject: json))
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

private final class DeferredTodoURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredTodoURLProtocol] = []
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

import XCTest
@testable import Life_USTC

final class ServerWorkspaceTests: XCTestCase {
    private var client: ServerClient!
    private var tokens: MockTokenStore!
    private let timestamp = "2035-09-15T10:30:00+08:00"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        tokens = MockTokenStore()
        tokens.accessToken = "workspace-owner"
        client = ServerClient(configuration: ServerClientConfiguration(
            baseURL: URL(string: "https://test.example.com")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        tokens = nil
        super.tearDown()
    }

    func testAllTodosExhaustsPagesAndRetainsGlobalCountsAndFilters() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = self.query(request)
            let page = Int(query["page"] ?? "0")!
            XCTAssertEqual(request.url?.path, "/api/workspace/todos")
            XCTAssertEqual(query["pageSize"], "100")
            XCTAssertEqual(query["completed"], "false")
            XCTAssertEqual(query["priority"], "high")
            XCTAssertNil(query["limit"])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer workspace-owner")
            return try self.response(request, [
                "meta": ["counts": ["completed": 2, "incomplete": 205, "overdue": 3]],
                "data": ((page - 1) * 100..<min(page * 100, 205)).map { self.todo("todo-\($0)") },
                "pagination": self.pagination(page: page, size: 100, total: 205, pages: 3),
            ])
        }
        let result = try await client.fetchAllTodos(filters: .init(completed: false, priority: .high))
        XCTAssertEqual(result.todos.map(\.id), (0..<205).map { "todo-\($0)" })
        XCTAssertEqual(result.counts, ServerTodoCounts(completed: 2, incomplete: 205, overdue: 3))
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)
    }

    func testTodoPatchDistinguishesOmittedNullAndValue() async throws {
        MockURLProtocol.stubJSON(["success": true, "todo": todo("todo-1")])
        let updated = try await client.updateTodo(id: "todo-1", request: UpdateTodoRequest(
            content: .null, dueAt: .null, completed: false
        ))
        XCTAssertEqual(updated.id, "todo-1")
        XCTAssertNil(updated.content)
        XCTAssertNil(updated.dueAt)
        var request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(request.httpMethod, "PATCH")
        var body = try requestBody(request)
        XCTAssertTrue(body["content"] is NSNull)
        XCTAssertTrue(body["dueAt"] is NSNull)
        XCTAssertEqual(body["completed"] as? Bool, false)
        XCTAssertEqual(Set(body.keys), ["content", "dueAt", "completed"])

        _ = try await client.updateTodo(id: "todo-1", request: UpdateTodoRequest(completed: true))
        request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        body = try requestBody(request)
        XCTAssertEqual(Set(body.keys), ["completed"])
        XCTAssertEqual(body["completed"] as? Bool, true)

        _ = try await client.updateTodo(id: "todo-1", request: UpdateTodoRequest(
            title: "Edited", content: .value("Chapter 2"), priority: "high", dueAt: .value(timestamp)
        ))
        body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(body["title"] as? String, "Edited")
        XCTAssertEqual(body["content"] as? String, "Chapter 2")
        XCTAssertEqual(body["dueAt"] as? String, timestamp)
        XCTAssertNil(body["completed"])

    }

    func testTodoCreateUsesIDResponseAndDeleteUsesExactMethod() async throws {
        MockURLProtocol.stubJSON(["id": "created-todo"], statusCode: 201)
        let id = try await client.createTodo(CreateTodoRequest(title: "Read", content: "Chapter 1", priority: "low", dueAt: timestamp))
        XCTAssertEqual(id, "created-todo")
        let create = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(create.httpMethod, "POST")
        XCTAssertEqual(create.url?.path, "/api/workspace/todos")
        XCTAssertEqual(try requestBody(create)["dueAt"] as? String, timestamp)
        MockURLProtocol.stubJSON(["success": true])
        try await client.deleteTodo(id: id)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "DELETE")
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path, "/api/workspace/todos/created-todo")
    }

    func testSubscribedHomeworkPaginationPreservesSectionEditorsAndCompletionWithoutPublicMeta() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = self.query(request)
            let page = Int(query["page"] ?? "0")!
            XCTAssertEqual(request.url?.path, "/api/workspace/homeworks")
            XCTAssertEqual(query["pageSize"], "50")
            XCTAssertEqual(Set(query.keys), ["page", "pageSize"])
            return try self.response(request, [
                "data": ((page - 1) * 50..<min(page * 50, 51)).map { self.homework("homework-\($0)", completed: $0 == 50) },
                "pagination": self.pagination(page: page, size: 50, total: 51, pages: 2),
            ])
        }
        let items = try await client.fetchAllSubscribedHomeworks()
        XCTAssertEqual(items.map(\.id), (0..<51).map { "homework-\($0)" })
        let last = try XCTUnwrap(items.last)
        XCTAssertEqual(last.section?.jwId, 42)
        XCTAssertEqual(last.section?.course.nameCn, "数学")
        XCTAssertEqual(last.section?.semester?.code, "2035-fall")
        XCTAssertEqual(last.updatedBy?.id, "editor")
        XCTAssertEqual(last.updatedById, "editor")
        XCTAssertEqual(last.completion?.completedAt, date(timestamp))
        XCTAssertFalse(last.isPending(at: date(timestamp)))
    }

    func testHomeworkPageSizeRejectsBeyondServerBoundBeforeNetwork() async throws {
        do {
            let _ = try await client.fetchSubscribedHomeworksPage(pageSize: 51)
            XCTFail("Homework pagination must respect the server's 50-row bound")
        } catch ServerError.badRequest { }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    func testTeachingAssistantPendingStateUsesExactDeadlineAndActualCompletion() throws {
        func decode(dueAt: String?, completed: Bool = false) throws -> ServerHomework {
            var object = homework("ta", completed: completed)
            object["completionRequired"] = false
            object["submissionDueAt"] = dueAt.map { $0 as Any } ?? NSNull()
            return try client.decoder.decode(ServerHomework.self, from: JSONSerialization.data(withJSONObject: object))
        }
        XCTAssertTrue(try decode(dueAt: "2035-09-15T10:30:01+08:00").isPending(at: date(timestamp)))
        XCTAssertFalse(try decode(dueAt: timestamp).isPending(at: date(timestamp)))
        XCTAssertFalse(try decode(dueAt: "2035-09-15T10:29:59+08:00").isPending(at: date(timestamp)))
        XCTAssertTrue(try decode(dueAt: nil).isPending(at: date(timestamp)))
        XCTAssertFalse(try decode(dueAt: nil, completed: true).isPending(at: date(timestamp)))
    }

    func testOldWorkspaceWritesCannotUseReplacementAccount() async throws {
        let revision = client.sessionRevision
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: revision)
        for operation in 0..<4 {
            do {
                switch operation {
                case 0:
                    _ = try await client.createTodo(CreateTodoRequest(title: "Old draft", content: nil, priority: "low", dueAt: nil), expectedRevision: revision)
                case 1:
                    _ = try await client.updateTodo(id: "old-todo", request: UpdateTodoRequest(completed: true), expectedRevision: revision)
                case 2:
                    try await client.deleteTodo(id: "old-todo", expectedRevision: revision)
                default:
                    _ = try await client.setHomeworkCompletion(id: "homework", completed: true, expectedRevision: revision)
                }
                XCTFail("A queued old write must not use the replacement account")
            } catch is CancellationError { }
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        XCTAssertEqual(client.accessToken, "second-owner")
    }

    func testHomeworkCompletionKeepsServerTimestampAndReopenClearsIt() async throws {
        MockURLProtocol.stubJSON(["completed": true, "completedAt": timestamp])
        for _ in 0..<2 {
            let result = try await client.setHomeworkCompletion(id: "homework-1", completed: true)
            XCTAssertTrue(result.completed)
            XCTAssertEqual(result.completedAt, date(timestamp))
        }
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/workspace/homeworks/homework-1/completion")
        XCTAssertEqual(try requestBody(request)["completed"] as? Bool, true)
        MockURLProtocol.stubJSON(["completed": false, "completedAt": NSNull()])
        let reopened = try await client.setHomeworkCompletion(id: "homework-1", completed: false)
        XCTAssertFalse(reopened.completed)
        XCTAssertNil(reopened.completedAt)
    }

    func testExamPaginationPreservesUnknownDatesAndAllFilterParameters() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = self.query(request)
            let page = Int(query["page"] ?? "0")!
            XCTAssertEqual(request.url?.path, "/api/workspace/exams")
            XCTAssertEqual(query["pageSize"], "100")
            XCTAssertEqual(query["semesterId"], "8")
            XCTAssertEqual(query["includeDateUnknown"], "true")
            XCTAssertEqual(query["dateFrom"], "2035-09-01")
            XCTAssertEqual(query["dateTo"], "2035-10-01")
            XCTAssertEqual(query["locale"], "zh-cn")
            return try self.response(request, [
                "data": ((page - 1) * 100..<min(page * 100, 101)).map { self.exam($0, dateUnknown: $0 == 100) },
                "pagination": self.pagination(page: page, size: 100, total: 101, pages: 2),
            ])
        }
        let items = try await client.fetchAllSubscribedExams(filters: .init(
            semesterID: 8, dateFrom: "2035-09-01", dateTo: "2035-10-01", locale: "zh-cn"
        ))
        XCTAssertEqual(items.map(\.id), Array(0..<101))
        XCTAssertEqual(items.first?.examDate, date(timestamp))
        XCTAssertNil(items.last?.examDate)
        XCTAssertNil(items.last?.startTime)
        XCTAssertEqual(items.last?.section.jwId, 42)
        XCTAssertEqual(items.last?.examRooms.first?.room, "Exam Lab")
    }

    func testActionableOverviewDecodesFlattenedFocusAndEveryDeadlineGroup() async throws {
        var focus = event("schedule", id: "current", target: "section", targetID: "42")
        focus["status"] = "now"
        focus["subscriptionKind"] = "teaching_assistant"
        focus["teachers"] = ["教师"]
        focus["sectionJwId"] = 42
        focus["sectionCode"] = "MATH101.01"
        let today = event("todo_due", id: "today", target: "todo", targetID: "todo-1")
        var unknown = event("exam", id: "exam", target: "exam", targetID: "7")
        unknown["hasTime"] = false
        var undated = event("homework_due", id: "undated", target: "homework", targetID: "homework-1")
        undated["at"] = NSNull()
        undated["hasTime"] = false
        undated["completionRequired"] = false
        MockURLProtocol.stubJSON([
            "anchor": ["atTime": timestamp, "dateFrom": "2035-09-15T00:00:00+08:00", "dateTo": "2035-09-22T00:00:00+08:00"],
            "focus": focus, "urgency": [today], "upcoming": [unknown],
            "deadlines": ["today": [today], "nextThreeDays": [], "allPending": [today, undated]],
            "subscriptions": ["totalCount": 3, "currentSemesterCount": 0, "currentSemester": NSNull()],
        ])
        let overview = try await client.fetchActionableOverview(atTime: date(timestamp), locale: "zh-cn")
        XCTAssertEqual(overview.focus?.status, .now)
        XCTAssertEqual(overview.focus?.event.target, ServerCalendarTarget(kind: .section, id: "42"))
        XCTAssertEqual(overview.focus?.event.subscriptionKind, .teachingAssistant)
        XCTAssertEqual(overview.focus?.event.teachers, ["教师"])
        XCTAssertEqual(overview.upcoming.first?.hasTime, false)
        XCTAssertEqual(overview.deadlines.allPending.count, 2)
        XCTAssertNil(overview.deadlines.allPending.last?.at)
        XCTAssertEqual(overview.deadlines.allPending.last?.completionRequired, false)
        XCTAssertEqual(overview.subscriptions.currentSemesterCount, 0)
        XCTAssertEqual(overview.subscriptions.totalCount, 3)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(request.url?.path, "/api/workspace/overview/actionable")
        XCTAssertEqual(query(request)["atTime"], "2035-09-15T02:30:00Z")
        XCTAssertEqual(query(request)["locale"], "zh-cn")
    }

    func testCalendarFeedUsesExactServerURLAndNeverConstructsItFromPath() async throws {
        let exact = "https://feeds.example.net/api/calendar-feeds/personal/opaque-test-token.ics?version=2"
        MockURLProtocol.stubJSON(["subscription": ["userId": "owner", "sections": [], "calendarPath": "/different-path", "calendarUrl": exact]])
        let url = try await client.fetchPersonalCalendarFeedURL()
        XCTAssertEqual(url?.absoluteString, exact)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/api/workspace/subscriptions/current")
        MockURLProtocol.stubJSON(["subscription": ["userId": "owner", "sections": [], "calendarPath": "/api/calendar-feeds/hidden.ics", "calendarUrl": NSNull()]])
        let hidden = try await client.fetchPersonalCalendarFeedURL()
        XCTAssertNil(hidden)
        MockURLProtocol.stubJSON(["subscription": NSNull()])
        let absent = try await client.fetchPersonalCalendarFeedURL()
        XCTAssertNil(absent)
    }

    func testLaterPageFailureDoesNotReturnIncompleteHomeworkCollection() async throws {
        MockURLProtocol.requestHandler = { request in
            if self.query(request)["page"] == "2" {
                return try self.response(request, ["error": "Temporarily unavailable"], status: 503)
            }
            return try self.response(request, ["data": [self.homework("first")], "pagination": self.pagination(page: 1, size: 50, total: 2, pages: 2)])
        }
        do {
            let _ = try await client.fetchAllSubscribedHomeworks()
            XCTFail("A failed later page must not turn into a partial successful list")
        } catch ServerError.serverError(let message) {
            XCTAssertEqual(message, "Temporarily unavailable")
        }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testLogoutDuringLaterPageCancelsTheEntireWorkspaceRead() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            let page = Int(self.query(request)["page"] ?? "0")!
            if page == 2 { client.clearTokens() }
            return try self.response(request, ["data": [self.homework("page-\(page)")], "pagination": self.pagination(page: page, size: 50, total: 2, pages: 2)])
        }
        do {
            let _ = try await client.fetchAllSubscribedHomeworks()
            XCTFail("A collection must never mix or return data from a former account")
        } catch is CancellationError { }
        XCTAssertTrue(tokens.accessToken.isEmpty)
    }

    func testEverySuccessfulWorkspaceMutationPostsOneRefreshNotification() async throws {
        for operation in ["create", "update", "delete", "completion"] {
            let changed = expectation(description: "One refresh after \(operation)")
            changed.assertForOverFulfill = true
            let observer = NotificationCenter.default.addObserver(forName: .serverWorkspaceDidChange, object: nil, queue: .main) { _ in
                changed.fulfill()
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            switch operation {
            case "create": MockURLProtocol.stubJSON(["id": "created"], statusCode: 201)
            case "update": MockURLProtocol.stubJSON(["success": true, "todo": todo("updated")])
            case "delete": MockURLProtocol.stubJSON(["success": true])
            default: MockURLProtocol.stubJSON(["completed": true, "completedAt": timestamp])
            }
            try await performMutation(operation)
            NotificationCenter.default.removeObserver(observer)
            await fulfillment(of: [changed], timeout: 1)
        }
    }

    func testFailedWorkspaceMutationsDoNotPostSuccessNotifications() async throws {
        let changed = expectation(description: "No refresh for rejected writes")
        changed.isInverted = true
        let observer = NotificationCenter.default.addObserver(forName: .serverWorkspaceDidChange, object: nil, queue: .main) { _ in
            changed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        MockURLProtocol.stubJSON(["error": "Rejected write"], statusCode: 403)
        for operation in ["create", "update", "delete", "completion"] {
            do {
                try await performMutation(operation)
                XCTFail("Rejected \(operation) must report its failure")
            } catch ServerError.forbidden { }
        }
        await fulfillment(of: [changed], timeout: 0.05)
    }

    private func performMutation(_ operation: String) async throws {
        switch operation {
        case "create": _ = try await client.createTodo(CreateTodoRequest(title: "Read", content: nil, priority: nil, dueAt: nil))
        case "update": _ = try await client.updateTodo(id: "todo", request: UpdateTodoRequest(completed: true))
        case "delete": try await client.deleteTodo(id: "todo")
        default: _ = try await client.setHomeworkCompletion(id: "homework", completed: true)
        }
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func pagination(page: Int, size: Int, total: Int, pages: Int) -> [String: Int] {
        ["page": page, "pageSize": size, "total": total, "totalPages": pages]
    }

    private func todo(_ id: String) -> [String: Any] {
        ["id": id, "title": id, "content": NSNull(), "priority": "high", "completed": false, "dueAt": NSNull(), "createdAt": timestamp, "updatedAt": timestamp]
    }

    private func section() -> [String: Any] {
        ["id": 7, "jwId": 42, "code": "MATH101.01", "courseId": 9, "semesterId": 8,
         "course": ["id": 9, "jwId": 99, "code": "MATH101", "nameCn": "数学"],
         "semester": ["id": 8, "code": "2035-fall", "nameCn": "2035秋"]]
    }

    private func homework(_ id: String, completed: Bool = false) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": id, "isMajor": false, "requiresTeam": false,
         "completionRequired": true, "submissionDueAt": timestamp, "createdAt": timestamp, "updatedAt": timestamp,
         "description": ["id": "description", "content": "Homework detail"], "section": section(),
         "updatedById": "editor", "updatedBy": ["id": "editor", "name": "Editor"],
         "completion": completed ? ["completedAt": timestamp] : NSNull(), "commentCount": 2]
    }

    private func exam(_ id: Int, dateUnknown: Bool) -> [String: Any] {
        ["id": id, "jwId": id + 1000, "sectionId": 7,
         "examDate": dateUnknown ? NSNull() : timestamp as Any,
         "startTime": dateUnknown ? NSNull() : 1000 as Any,
         "endTime": dateUnknown ? NSNull() : 1100 as Any,
         "examMode": "闭卷", "section": section(), "examRooms": [["id": 1, "room": "Exam Lab", "count": 30]]]
    }

    private func event(_ type: String, id: String, target: String, targetID: String) -> [String: Any] {
        ["id": id, "type": type, "at": timestamp, "endsAt": NSNull(), "title": id,
         "location": NSNull(), "url": "/workspace", "youngId": NSNull(),
         "target": ["kind": target, "id": targetID], "hasTime": true]
    }

    private func response(_ request: URLRequest, _ body: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, try JSONSerialization.data(withJSONObject: body))
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

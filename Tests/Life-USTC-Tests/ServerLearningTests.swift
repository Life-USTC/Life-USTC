import XCTest
@testable import Life_USTC

final class ServerLearningTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "test-access-token"
        client = ServerClient(configuration: ServerClientConfiguration(
            baseURL: URL(string: "https://test.example.com")!,
            session: MockURLProtocol.mockSession(),
            tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        super.tearDown()
    }

    func testSubscriptionListRetainsHistoryAndEveryRole() async throws {
        MockURLProtocol.stubJSON([
            "subscription": [
                "userId": "user-1",
                "sections": [
                    ["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular",
                     "semester": ["id": 2, "code": "2026-1", "nameCn": "Autumn 2026"]],
                    ["id": 8, "jwId": 43, "code": "PHYS101.01", "kind": "auditor",
                     "semester": ["id": 1, "code": "2025-1", "nameCn": "Autumn 2025"]],
                    ["id": 9, "jwId": 44, "code": "CS101.01", "kind": "teaching_assistant"],
                ],
            ],
        ])
        let sections = try await client.fetchLearningSubscriptions()
        XCTAssertEqual(sections.map(\.jwId), [42, 43, 44])
        XCTAssertEqual(sections.map(\.kind), [.regular, .auditor, .teachingAssistant])
        XCTAssertEqual(sections[1].semester?.code, "2025-1")
        XCTAssertNil(sections[2].semester)
    }

    func testAppendOnlySendsTheSelectedInternalSectionID() async throws {
        MockURLProtocol.stubJSON([
            "subscription": [
                "userId": "user-1",
                "sections": [
                    ["id": 8, "jwId": 43, "code": "PHYS101.01", "kind": "teaching_assistant"],
                    ["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular"],
                ],
            ],
            "addedCount": 1, "alreadySubscribedCount": 0,
        ])
        try await client.appendSectionSubscription(sectionID: 7)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1, "Appending must not read and replace the complete subscription set")
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions")
        let body = try requestBody(request)
        XCTAssertEqual(body["sectionIds"] as? [Int], [7])
        XCTAssertEqual(Set(body.keys), ["sectionIds"])
    }

    func testRemovingLastSubscriptionAcceptsNullSubscription() async throws {
        MockURLProtocol.stubJSON(["subscription": NSNull()])
        try await client.removeSectionSubscription(sectionID: 7)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions")
        XCTAssertEqual(try requestBody(request)["sectionIds"] as? [Int], [7])
    }

    func testKindUpdateUsesTeachingSectionJWIDAndDoesNotReplaceMembership() async throws {
        MockURLProtocol.stubJSON(["sectionJwId": 42, "kind": "auditor"])
        try await client.updateSectionSubscriptionKind(jwID: 42, kind: .auditor)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions/42")
        let body = try requestBody(request)
        XCTAssertEqual(body["kind"] as? String, "auditor")
        XCTAssertEqual(Set(body.keys), ["kind"])
    }

    func testSemesterPickerLoadsLaterPages() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let page = Int(query.first { $0.name == "page" }?.value ?? "0")!
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [["id": page, "code": "term-\(page)", "nameCn": "Term \(page)"]],
                "pagination": ["page": page, "pageSize": 100, "total": 2, "totalPages": 2],
            ])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let semesters = try await client.fetchAllSemesters()
        XCTAssertEqual(semesters.map(\.id), [1, 2])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    @MainActor
    func testCatalogPaginationAppendsAndNewSearchReplacesPreviousResults() async throws {
        MockURLProtocol.requestHandler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let page = Int(query.first { $0.name == "page" }?.value ?? "0")!
            let isSearch = query.first { $0.name == "search" }?.value == "Physics"
            let id = isSearch ? 20 : page
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [["id": id, "jwId": id + 40, "code": "SECTION-\(id)"]],
                "pagination": ["page": page, "pageSize": 30, "total": isSearch ? 1 : 2, "totalPages": isSearch ? 1 : 2],
            ])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let model = ServerCatalogModel(client: client)
        model.semesterID = 5
        await model.load()
        XCTAssertTrue(model.hasMore)
        await model.load(append: true)
        XCTAssertEqual(model.sections.map(\.id), [1, 2])
        XCTAssertFalse(model.hasMore)
        model.search = "  Physics  "
        await model.load()
        XCTAssertEqual(model.sections.map(\.id), [20])
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "search" }?.value, "Physics")
        XCTAssertEqual(query.first { $0.name == "semesterId" }?.value, "5")
        XCTAssertEqual(query.first { $0.name == "page" }?.value, "1")
    }

    @MainActor
    func testSectionDetailLoadsMoreThanTwoHundredMeetingsBySectionJWID() async throws {
        stubSectionSchedulePages()
        let model = ServerSectionDetailModel(jwId: 42, client: client)

        await model.load()

        XCTAssertEqual(model.schedules.map(\.id), Array(1...201))
        XCTAssertEqual(model.schedules.last?.room?.namePrimary, "Room 201")
        XCTAssertEqual(model.schedules.last?.teachers?.first?.nameCn, "Schedule teacher")
        XCTAssertNil(model.scheduleError)
        let requests = MockURLProtocol.capturedRequests.filter { $0.url?.path == "/api/catalog/sections/42/schedules" }
        let queries = requests.map {
            URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        }
        XCTAssertEqual(queries.map { $0.first { $0.name == "page" }?.value }, ["1", "2", "3"])
        XCTAssertTrue(queries.allSatisfy { $0.first { $0.name == "pageSize" }?.value == "100" })
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.url?.path == "/api/catalog/schedules" })
    }

    @MainActor
    func testRetiredSectionDetailKeepsLaterMeetingsAndRooms() async throws {
        stubSectionSchedulePages(retired: true)
        let model = ServerSectionDetailModel(jwId: 42, client: client)

        await model.load()

        XCTAssertEqual(model.schedules.map(\.id), Array(1...201))
        XCTAssertEqual(model.schedules.last?.room?.namePrimary, "Room 201")
        XCTAssertEqual(model.schedules.last?.teachers?.first?.nameCn, "Schedule teacher")
        XCTAssertNil(model.scheduleError)
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.url?.path == "/api/catalog/schedules" })
    }

    @MainActor
    func testSectionDetailDoesNotPresentAnIncompleteSchedulePageAsComplete() async throws {
        stubSectionSchedulePages(failingPage: 2)
        let model = ServerSectionDetailModel(jwId: 42, client: client)

        await model.load()

        XCTAssertEqual(model.section?.id, 7)
        XCTAssertTrue(model.schedules.isEmpty)
        XCTAssertEqual(model.scheduleError, "Schedule page unavailable")
        XCTAssertTrue(model.subscriptionReadSucceeded)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedSubscriptionWriteDoesNotShowSubscribedState() async throws {
        MockURLProtocol.requestHandler = { request in
            let body: Any
            let status: Int
            switch request.url!.path {
            case "/api/catalog/sections/42":
                body = ["id": 7, "jwId": 42, "code": "MATH101.01"]
                status = 200
            case "/api/catalog/sections/42/schedules":
                body = ["data": [], "pagination": ["page": 1, "pageSize": 100, "total": 0, "totalPages": 0]]
                status = 200
            case "/api/workspace/subscriptions/current":
                body = ["subscription": ["sections": []]]
                status = 200
            default:
                body = ["error": "Retry fixture failure"]
                status = 503
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                try JSONSerialization.data(withJSONObject: body)
            )
        }
        let model = ServerSectionDetailModel(jwId: 42, client: client)
        await model.load()
        XCTAssertTrue(model.subscriptionReadSucceeded)
        await model.toggleSubscription()
        XCTAssertNil(model.subscription)
        XCTAssertTrue(model.subscriptionReadSucceeded)
        XCTAssertEqual(model.subscriptionError, "Retry fixture failure")
        XCTAssertFalse(model.isSaving)
    }

    @MainActor
    func testSignOutClearsOwnedSubscriptionsWithoutPrivateRead() async throws {
        MockURLProtocol.stubJSON([
            "subscription": ["sections": [["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular"]]],
        ])
        let model = ServerSubscriptionsModel(client: client)
        await model.load()
        XCTAssertEqual(model.sections.count, 1)
        client.clearTokens()
        MockURLProtocol.reset()
        await model.load()
        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testSubscriptionSemesterFilterRetainsHistoryAndResetsAfterEmptyRead() async {
        MockURLProtocol.stubJSON([
            "subscription": ["sections": [
                ["id": 8, "jwId": 43, "code": "PHYS101.01", "kind": "auditor",
                 "semester": ["id": 1, "code": "2025-FALL", "nameCn": "Autumn 2025",
                              "startDate": "2025-09-01T00:00:00+08:00"]],
                ["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular",
                 "semester": ["id": 2, "code": "2026-FALL", "nameCn": "Autumn 2026",
                              "startDate": "2026-09-01T00:00:00+08:00"]],
            ]],
        ])
        let model = ServerSubscriptionsModel(client: client)
        await model.load()

        XCTAssertEqual(model.semesters.map(\.id), [2, 1])
        XCTAssertEqual(Set(model.filteredSections.map(\.jwId)), [42, 43])
        model.semesterID = 2
        XCTAssertEqual(model.filteredSections.map(\.jwId), [42])
        model.semesterID = 1
        XCTAssertEqual(model.filteredSections.map(\.jwId), [43])
        XCTAssertEqual(model.filteredSections.first?.kind, .auditor)

        MockURLProtocol.stubJSON(["subscription": NSNull()])
        await model.load()

        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertTrue(model.filteredSections.isEmpty)
        XCTAssertTrue(model.semesters.isEmpty)
        XCTAssertNil(model.semesterID)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedSubscriptionReadIsDistinctFromSuccessfulEmptyRead() async {
        let model = ServerSubscriptionsModel(client: client)
        MockURLProtocol.stubJSON(["error": "Subscription read unavailable"], statusCode: 503)
        await model.load()

        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertEqual(model.error, "Subscription read unavailable")
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(["subscription": ["sections": []]])
        await model.load()

        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testUnauthorizedSubscriptionReadPreventsMembershipWrites() async {
        for status in [401, 403] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                let body: Any
                let responseStatus: Int
                switch request.url!.path {
                case "/api/catalog/sections/42":
                    body = ["id": 7, "jwId": 42, "code": "MATH101.01"]
                    responseStatus = 200
                case "/api/catalog/sections/42/schedules":
                    body = ["data": [], "pagination": ["page": 1, "pageSize": 100, "total": 0, "totalPages": 0]]
                    responseStatus = 200
                default:
                    body = ["error": "Subscription access denied"]
                    responseStatus = status
                }
                return (
                    HTTPURLResponse(url: request.url!, statusCode: responseStatus, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body)
                )
            }
            let model = ServerSectionDetailModel(jwId: 42, client: client)
            await model.load()

            XCTAssertEqual(model.section?.jwId, 42, "Public detail remains available after a \(status) private read")
            XCTAssertFalse(model.subscriptionReadSucceeded)
            XCTAssertNil(model.subscription)
            XCTAssertNotNil(model.subscriptionError)
            if status == 403 { XCTAssertEqual(model.subscriptionError, "Subscription access denied") }
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)

            await model.toggleSubscription()
            await model.setKind(.auditor)

            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3, "Unknown membership must not be mutated after \(status)")
            XCTAssertTrue(MockURLProtocol.capturedRequests.allSatisfy { $0.httpMethod == "GET" })
            XCTAssertFalse(model.isSaving)
        }
    }

    private func stubSectionSchedulePages(failingPage: Int? = nil, retired: Bool = false) {
        let schedules: [[String: Any]] = (1...201).map { id in
            ["id": id, "date": "2026-10-23", "weekday": 5, "startTime": 815, "endTime": 945,
             "room": ["id": id, "namePrimary": "Room \(id)"],
             "teachers": [["id": 3, "nameCn": "Schedule teacher"]]]
        }
        MockURLProtocol.requestHandler = { request in
            let body: Any
            var status = 200
            switch request.url!.path {
            case "/api/catalog/sections/42":
                body = ["id": 7, "jwId": 42, "code": "MATH101.01",
                        "retiredAt": retired ? "2026-10-20T00:00:00+08:00" as Any : NSNull()]
            case "/api/catalog/sections/42/schedules":
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let page = Int(query.first { $0.name == "page" }?.value ?? "0") ?? 0
                if page == 0 {
                    // Existing callers keep the server's legacy 200-meeting array response.
                    body = Array(schedules.prefix(200))
                } else if page == failingPage {
                    status = 503
                    body = ["error": "Schedule page unavailable"]
                } else {
                    guard (1...3).contains(page),
                          query.first(where: { $0.name == "pageSize" })?.value == "100"
                    else { throw URLError(.badURL) }
                    body = ["data": Array(schedules[((page - 1) * 100)..<min(page * 100, schedules.count)]),
                            "pagination": ["page": page, "pageSize": 100, "total": 201, "totalPages": 3]]
                }
            case "/api/workspace/subscriptions/current":
                body = ["subscription": ["sections": []]]
            default:
                status = 404
                body = ["error": "Unexpected fixture request"]
            }
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
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
                XCTAssertGreaterThanOrEqual(count, 0)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

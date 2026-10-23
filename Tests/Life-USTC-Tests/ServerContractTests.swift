import XCTest
@testable import Life_USTC

final class ServerContractTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        client = ServerClient(configuration: ServerClientConfiguration(
            baseURL: URL(string: "https://test.example.com")!,
            session: MockURLProtocol.mockSession(),
            tokenStore: MockTokenStore()
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        super.tearDown()
    }

    func testExistingEndpointsUseCurrentDomains() {
        let endpoints: [(ServerEndpoint, String)] = [
            (.me, "/api/account/profile"),
            (.overview, "/api/workspace/overview"),
            (.currentSemester, "/api/catalog/semesters/current"),
            (.getCourse(jwId: "42"), "/api/catalog/courses/42"),
            (.getSubscriptions, "/api/workspace/subscriptions/current"),
            (.listTodos, "/api/workspace/todos"),
            (.metadata, "/api/catalog/metadata"),
        ]
        for (endpoint, expectedPath) in endpoints {
            XCTAssertEqual(endpoint.path, expectedPath)
        }
    }

    func testCatalogSearchIsNotSilentlyIgnored() {
        for endpoint in [
            ServerEndpoint.listCourses(query: "数学", page: 2, pageSize: 20),
            .listSections(query: "数学", semesterId: 1, courseId: nil, page: 2, pageSize: 20),
            .listTeachers(query: "数学", page: 2, pageSize: 20),
        ] {
            let query = Dictionary(uniqueKeysWithValues: (endpoint.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(query["search"], "数学")
            XCTAssertFalse(query.keys.contains("q"))
            XCTAssertEqual(query["page"], "2")
        }
    }

    func testSectionRequestsIncludeCurriculumAndExamData() {
        let query = Dictionary(uniqueKeysWithValues: (ServerEndpoint.getSection(jwId: "42").queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(query["includeSchedules"], "true")
        XCTAssertEqual(query["includeExams"], "true")
    }

    func testProfileAllowsUnpublishedEmailAndAdminFlag() async throws {
        MockURLProtocol.stubJSON([
            "id": "user-1", "email": NSNull(), "name": "User",
            "isAdmin": NSNull(), "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
        ])
        let user: ServerUser = try await client.request(.me)
        XCTAssertEqual(user.id, "user-1")
        XCTAssertNil(user.email)
    }

    func testHomeworkDetailUnwrapsCurrentResponse() async throws {
        MockURLProtocol.stubJSON([
            "homework": [
                "id": "homework-1", "sectionId": 42, "title": "习题",
                "isMajor": false, "requiresTeam": false, "completionRequired": true,
                "createdAt": "2026-10-01T00:00:00Z", "updatedAt": "2026-10-02T00:00:00Z",
            ],
            "auditLogs": [],
        ])
        let homework = try await client.fetchHomework(id: "homework-1")
        XCTAssertEqual(homework.title, "习题")
    }

    func testSectionSchedulesAllowFractionalPeriods() async throws {
        MockURLProtocol.stubJSON([
            "id": 1, "jwId": 42, "code": "MATH001.01",
            "schedules": [[
                "id": 5, "periods": 1.5, "weekday": 1,
                "startTime": "08:00", "endTime": "09:30", "weekIndex": 3,
                "startUnit": 1, "endUnit": 2,
            ]],
            "exams": [],
        ])
        let section = try await client.fetchSectionDetail(jwId: "42")
        XCTAssertEqual(section.schedules?.count, 1)
        XCTAssertEqual(section.schedules?.first?.startTime.components.hour, 8)
    }

    func testSubscriptionImportUsesOneAdditiveRequestAndRetainsAllRoles() async throws {
        MockURLProtocol.stubJSON([
            "success": true,
            "semester": ["id": 1, "nameCn": NSNull(), "code": NSNull()],
            "matchedCodes": ["MATH001.01"], "unmatchedCodes": ["UNKNOWN"], "ambiguousCodes": [],
            "sections": [["id": 3, "jwId": 103, "code": "MATH001.01"]],
            "addedCount": 1, "alreadySubscribedCount": 0,
            "subscription": [
                "userId": "user-1", "note": "",
                "sections": [
                    ["id": 1, "jwId": 101, "code": "CS001.01", "kind": "auditor"],
                    ["id": 2, "jwId": 102, "code": "PHYS001.01", "kind": "teaching_assistant"],
                    ["id": 3, "jwId": 103, "code": "MATH001.01", "kind": "regular"],
                ],
            ],
        ])

        let response = try await client.importSubscriptions(codes: ["MATH001.01", "UNKNOWN"], semesterId: 1)

        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions/import-codes")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try requestBody(request)
        XCTAssertEqual(body["codes"] as? [String], ["MATH001.01", "UNKNOWN"])
        XCTAssertEqual(body["semesterId"] as? Int, 1)
        XCTAssertNil(body["sectionIds"])
        XCTAssertEqual(response.subscription?.sections.map(\.kind), [.auditor, .teachingAssistant, .regular])
        XCTAssertEqual(response.unmatchedCodes, ["UNKNOWN"])
    }

    func testHomeworkCompletionUsesWorkspacePut() async throws {
        MockURLProtocol.stubJSON(["completed": true, "completedAt": "2026-10-23T00:00:00Z"])
        let response: HomeworkCompletionResponse = try await client.request(
            .setHomeworkCompletion(id: "homework-1", HomeworkCompletionRequest(completed: true))
        )
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/workspace/homeworks/homework-1/completion")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(try requestBody(request)["completed"] as? Bool, true)
        XCTAssertTrue(response.completed)
    }

    func testSharedAndSubscribedHomeworkListsHaveSeparateContracts() async throws {
        let pagination: [String: Any] = ["page": 2, "pageSize": 10, "total": 0, "totalPages": 0]
        MockURLProtocol.stubJSON([
            "data": [], "pagination": pagination,
            "meta": ["viewer": ["userId": "user-1", "isAdmin": false]],
        ])
        let shared = try await client.fetchHomeworks(sectionId: 42, page: 2, pageSize: 10)
        XCTAssertEqual(shared.meta.viewer.userId, "user-1")
        XCTAssertEqual(shared.pagination.page, 2)
        let sharedRequest = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(sharedRequest.url?.path, "/api/community/section-homeworks")
        XCTAssertEqual(URLComponents(url: sharedRequest.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "42")

        MockURLProtocol.stubJSON(["data": [], "pagination": pagination])
        let subscribed = try await client.fetchSubscribedHomeworks(page: 2, pageSize: 10)
        XCTAssertTrue(subscribed.data.isEmpty)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path, "/api/workspace/homeworks")
    }

    func testUploadListReadsPaginationAndNestedQuota() async throws {
        MockURLProtocol.stubJSON([
            "data": [["id": "upload-1", "key": "file-key", "filename": "notes.pdf", "size": 120, "createdAt": "2026-10-23T00:00:00Z"]],
            "pagination": ["page": 1, "pageSize": 20, "total": 1, "totalPages": 1],
            "meta": ["maxFileSizeBytes": 1024, "quotaBytes": 4096, "usedBytes": 120],
        ])
        let response: ServerUploadListResponse = try await client.request(.listUploads(page: 1, pageSize: 20))
        XCTAssertEqual(response.data.first?.filename, "notes.pdf")
        XCTAssertEqual(response.meta.usedBytes, 120)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/api/workspace/uploads")
    }

    func testScheduleQueryUsesRoomIdentityAndDateRange() {
        let endpoint = ServerEndpoint.querySchedules(sectionId: 42, teacherId: 3, roomId: 9, dateFrom: "2026-10-23", dateTo: "2026-10-24", weekday: nil)
        let query = Dictionary(uniqueKeysWithValues: (endpoint.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(query["roomId"], "9")
        XCTAssertEqual(query["dateFrom"], "2026-10-23")
        XCTAssertEqual(query["dateTo"], "2026-10-24")
        XCTAssertFalse(query.keys.contains("room"))
        XCTAssertFalse(query.keys.contains("date"))
    }

    func testLoginRequestsScopesNeededByExistingAppFeatures() {
        let scopes = Set(ServerAuth.scopes)
        XCTAssertTrue(Set([
            "account.profile:read", "workspace.subscription:read", "workspace.subscription:write",
            "workspace.todo:read", "workspace.todo:write", "workspace.calendar:read",
        ]).isSubset(of: scopes))
        XCTAssertFalse(scopes.contains { $0.hasPrefix("admin.") })
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

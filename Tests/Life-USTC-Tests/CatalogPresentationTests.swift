import XCTest
@testable import Life_USTC

final class CatalogPresentationTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRecognizedSemesterNamesFollowServerEnglishFormatting() {
        let english = Locale(identifier: "en_US")
        for (source, expected) in [("2026年春季学期", "Spring 2026"), (" 2025年秋季学期 ", "Fall 2025"),
                                   ("2026夏", "2026夏"), ("Fall 2026", "Fall 2026")] {
            let semester = ServerSemester(id: 1, jwId: 101, code: "code", nameCn: source, startDate: nil, endDate: nil)
            XCTAssertEqual(ServerCatalogDisplay.semesterName(semester, locale: english), expected)
            XCTAssertEqual(ServerCatalogDisplay.semesterName(semester, locale: Locale(identifier: "zh_CN")), source)
        }
    }

    func testEducationLevelCasingPreservesAcronyms() {
        for (source, expected) in [("undergraduate", "Undergraduate"), ("PhD", "PhD"),
                                   ("MBA", "MBA"), ("MSc programme", "MSc programme")] {
            let level = NamedEntity(id: 71, nameCn: "研究生", nameEn: source)
            XCTAssertEqual(ServerCatalogDisplay.educationLevelName(level, locale: Locale(identifier: "en_US")), expected)
            XCTAssertEqual(ServerCatalogDisplay.educationLevelName(level, locale: Locale(identifier: "zh_CN")), "研究生")
        }
    }

    @MainActor
    func testCourseEducationFilterUsesMetadataIDsAndResetsPagination() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            let body: Any
            if request.url?.path == "/api/catalog/metadata" {
                body = ["educationLevels": [["id": 71, "nameCn": "研究生", "nameEn": "PhD"]]]
            } else {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
                XCTAssertEqual(items.first { $0.name == "educationLevelId" }?.value, "71")
                XCTAssertEqual(items.first { $0.name == "page" }?.value, "1")
                body = ["data": [], "pagination": ["page": 1, "pageSize": 30, "total": 0, "totalPages": 0]]
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
        let model = ServerCatalogModel(client: client)
        await model.loadMetadata()
        XCTAssertEqual(model.educationLevels.map(\.id), [71])
        let previous = model.requestID
        model.kind = .courses
        model.educationLevelID = 71
        XCTAssertNotEqual(model.requestID, previous)
        await model.load()
        XCTAssertNil(model.error)
        XCTAssertFalse(model.hasMore)
    }

    @MainActor
    func testSubscriptionGroupsKeepEachOfferingWithItsSemesterAndTeachers() throws {
        let model = ServerSubscriptionsModel(client: makeClient())
        let raw = [
            ["id": 1, "jwId": 11, "code": "A.01", "kind": "regular", "semester": ["id": 2, "code": "2026", "nameCn": "2026年秋季学期"],
             "teachers": [["id": 9, "nameCn": "教师"]]],
            ["id": 2, "jwId": 12, "code": "A.02", "kind": "auditor", "semester": ["id": 2, "code": "2026", "nameCn": "2026年秋季学期"]],
            ["id": 3, "jwId": 13, "code": "B.01", "kind": "regular", "semester": ["id": 1, "code": "2025", "nameCn": "2025年秋季学期"]],
            ["id": 4, "jwId": 14, "code": "C.01", "kind": "regular"],
        ] as [[String: Any]]
        model.sections = try JSONDecoder().decode([ServerLearningSubscription].self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertEqual(model.groups.count, 3)
        XCTAssertEqual(model.groups.first { $0.id == 2 }?.sections.map(\.id), [1, 2])
        XCTAssertEqual(model.groups.first { $0.id == 1 }?.sections.map(\.id), [3])
        XCTAssertEqual(model.groups.first { $0.semester == nil }?.sections.map(\.id), [4])
        XCTAssertEqual(model.groups.first { $0.id == 2 }?.sections.first?.teachers?.first?.nameCn, "教师")
        model.semesterID = 1
        XCTAssertEqual(model.groups.map(\.id), [1])
    }

    @MainActor
    func testSubscriptionSnapshotRetainsRetirementStatusForCalendarExport() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions/current")
            let body: [String: Any] = ["subscription": ["sections": [
                ["id": 7, "jwId": 42, "code": "Historical.01", "kind": "regular", "retiredAt": "2026-01-01T00:00:00+08:00"],
                ["id": 8, "jwId": 43, "code": "Current.01", "kind": "regular", "retiredAt": NSNull()],
            ]]]
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
        let sections = try await client.fetchLearningSubscriptions()
        XCTAssertEqual(sections.map(\.id), [7, 8])
        XCTAssertEqual(sections.first?.retiredAt, ISO8601DateFormatter().date(from: "2025-12-31T16:00:00Z"))
        XCTAssertNil(sections.last?.retiredAt)
    }

    @MainActor
    func testRetiredSectionRemainsReadableWithoutOfferingNewMembership() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            let body: Any
            switch request.url!.path {
            case "/api/catalog/sections/42":
                body = ["id": 7, "jwId": 42, "code": "Historical.01", "retiredAt": "2026-01-01T00:00:00+08:00"]
            case "/api/catalog/sections/42/schedules":
                body = ["data": [], "pagination": ["page": 1, "pageSize": 100, "total": 0, "totalPages": 0]]
            case "/api/workspace/subscriptions/current": body = ["subscription": ["sections": []]]
            default: XCTFail("Unexpected membership write"); throw URLError(.badURL)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
        let model = ServerSectionDetailModel(jwId: 42, client: client)
        await model.load()
        XCTAssertNotNil(model.section?.retiredAt)
        XCTAssertTrue(model.subscriptionReadSucceeded)
        let reads = MockURLProtocol.capturedRequests.count
        await model.toggleSubscription()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, reads)
    }

    private func makeClient() -> ServerClient {
        let tokens = MockTokenStore()
        tokens.accessToken = "catalog-user"
        return ServerClient(configuration: .init(baseURL: URL(string: "https://catalog.example")!,
                                                 session: MockURLProtocol.mockSession(), tokenStore: tokens))
    }
}

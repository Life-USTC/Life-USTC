import XCTest
@testable import Life_USTC

final class PublicScheduleTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://schedules.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: MockTokenStore()
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testPublicQueryRetainsExactIdentitiesPaginationLocaleAndTeacherFacts() async throws {
        MockURLProtocol.stubJSON(page([schedule(1)], number: 2, total: 31))
        let response = try await client.querySchedules(
            sectionId: 7, teacherId: 3, roomId: 6,
            dateFrom: "2026-10-26", dateTo: "2026-10-30", weekday: 1,
            sectionJwId: 42, sectionCode: "MATH101.01", teacherCode: "T003", roomJwId: 2201,
            page: 2, pageSize: 30, locale: "en-us"
        )
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/catalog/schedules")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(query(request), [
            "sectionId": "7", "teacherId": "3", "roomId": "6",
            "dateFrom": "2026-10-26", "dateTo": "2026-10-30", "weekday": "1",
            "sectionJwId": "42", "sectionCode": "MATH101.01", "teacherCode": "T003", "roomJwId": "2201",
            "page": "2", "pageSize": "30", "locale": "en-us",
        ])
        let row = try XCTUnwrap(response.data.first)
        XCTAssertEqual(row.section?.jwId, 42)
        XCTAssertEqual(row.teachers?.map(\.id), [3, 4, 5])
        XCTAssertEqual(row.teacherParticipations?.map(\.id), [3, 4, 5])
        XCTAssertEqual(row.teacherParticipations?.first?.periods, 1.5)
        XCTAssertEqual(row.teacherParticipations?.first?.exerciseClass, true)
        XCTAssertEqual(row.teacherParticipations?[1].periods, 2.5)
        XCTAssertEqual(row.teacherParticipations?[1].exerciseClass, false)
        XCTAssertNil(row.teacherParticipations?.last?.periods)
        XCTAssertNil(row.teacherParticipations?.last?.exerciseClass)
        XCTAssertEqual(row.room?.namePrimary, "Room 2201")
    }

    @MainActor
    func testApplyingFiltersUsesCampusDatesAndKeepsDraftValuesOutOfRequests() async throws {
        let model = ServerPublicScheduleModel(client: client)
        MockURLProtocol.stubJSON(page([schedule(1)]))
        await model.load(locale: "zh-cn")
        XCTAssertEqual(query(try XCTUnwrap(MockURLProtocol.capturedRequests.last)), [
            "page": "1", "pageSize": "30", "locale": "zh-cn",
        ])
        var filters = ServerPublicScheduleFilters()
        filters.sectionCode = "  MATH101.01\n"
        filters.teacherCode = " T003 "
        filters.roomJWID = " 2201 "
        filters.weekday = 1
        filters.limitsDates = true
        filters.dateFrom = ISO8601DateFormatter().date(from: "2026-10-25T16:30:00Z")!
        filters.dateTo = ISO8601DateFormatter().date(from: "2026-10-30T15:30:00Z")!
        await model.apply(filters, locale: "en-us")
        XCTAssertEqual(query(try XCTUnwrap(MockURLProtocol.capturedRequests.last)), [
            "sectionCode": "MATH101.01", "teacherCode": "T003", "roomJwId": "2201", "weekday": "1",
            "dateFrom": "2026-10-26", "dateTo": "2026-10-30", "page": "1", "pageSize": "30", "locale": "en-us",
        ])
        XCTAssertEqual(model.filters.sectionCode, "MATH101.01")
        XCTAssertEqual(model.schedules.map(\.id), [1])
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testFailedNextPageRetainsRowsAndRetriesTheSamePage() async throws {
        let model = ServerPublicScheduleModel(client: client)
        MockURLProtocol.stubJSON(page([schedule(1)], total: 31))
        await model.load(locale: "en-us")
        XCTAssertTrue(model.hasMore)
        MockURLProtocol.stubJSON(["error": "Schedule unavailable"], statusCode: 503)
        await model.load(append: true, locale: "en-us")
        XCTAssertEqual(model.schedules.map(\.id), [1])
        XCTAssertEqual(model.error, "Schedule unavailable")
        XCTAssertTrue(model.hasMore)
        MockURLProtocol.stubJSON(page([schedule(31)], number: 2, total: 31))
        await model.load(append: true, locale: "en-us")
        XCTAssertEqual(model.schedules.map(\.id), [1, 31])
        XCTAssertEqual(MockURLProtocol.capturedRequests.map { query($0)["page"] }, ["1", "2", "2"])
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testChangingFiltersClearsEarlierRowsOnFailureAndCanReturnEmpty() async {
        let model = ServerPublicScheduleModel(client: client)
        MockURLProtocol.stubJSON(page([schedule(1)], total: 31))
        await model.load(locale: "en-us")
        var filters = ServerPublicScheduleFilters()
        filters.sectionCode = "MISSING"
        MockURLProtocol.stubJSON(["error": "Offline"], statusCode: 503)
        await model.apply(filters, locale: "en-us")
        XCTAssertTrue(model.schedules.isEmpty)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.total, 0)
        XCTAssertEqual(model.error, "Offline")
        MockURLProtocol.stubJSON(page([], total: 0))
        await model.load(locale: "en-us")
        XCTAssertTrue(model.schedules.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.filters.sectionCode, "MISSING")
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testInvalidRoomAndReversedDatesDoNotSendRequests() async {
        let model = ServerPublicScheduleModel(client: client)
        for value in ["not-a-room", "-1", "0", "99999999999999999999999999"] {
            var filters = ServerPublicScheduleFilters()
            filters.roomJWID = value
            XCTAssertNotNil(filters.validationError)
            await model.apply(filters, locale: "en-us")
        }
        var filters = ServerPublicScheduleFilters()
        filters.limitsDates = true
        filters.dateFrom = Date(timeIntervalSince1970: 1_000_000)
        filters.dateTo = Date(timeIntervalSince1970: 0)
        XCTAssertNotNil(filters.validationError)
        await model.apply(filters, locale: "en-us")
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testBackendChangeHidesRowsAndPreventsAppendingAnotherCatalog() async {
        let previousBaseURL = UserDefaults.standard.object(forKey: "serverBaseURL")
        defer { UserDefaults.standard.set(previousBaseURL, forKey: "serverBaseURL") }
        let model = ServerPublicScheduleModel(client: client)
        MockURLProtocol.stubJSON(page([schedule(1)], total: 31))
        await model.load(locale: "en-us")
        client.reconfigure(baseURL: URL(string: "https://other.example")!)
        XCTAssertTrue(model.schedules.isEmpty)
        await model.load(append: true, locale: "en-us")
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        MockURLProtocol.stubJSON(page([schedule(9)]))
        await model.load(locale: "zh-cn")
        XCTAssertEqual(model.schedules.map(\.id), [9])
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.host, "other.example")
    }

    @MainActor
    func testRepeatedPageIsRejectedWithoutDuplicatingRows() async {
        let model = ServerPublicScheduleModel(client: client)
        MockURLProtocol.stubJSON(page([schedule(1)], total: 31))
        await model.load(locale: "en-us")
        await model.load(append: true, locale: "en-us")
        XCTAssertEqual(model.schedules.map(\.id), [1])
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.hasMore)
    }

    @MainActor
    func testLatePreviousFilterResponseCannotReplaceNewResults() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredScheduleURLProtocol.self]
        let client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://schedules.example")!,
            session: URLSession(configuration: configuration), tokenStore: MockTokenStore()
        ))
        let model = ServerPublicScheduleModel(client: client)
        DeferredScheduleURLProtocol.requests = []
        defer {
            DeferredScheduleURLProtocol.requests = []
            DeferredScheduleURLProtocol.onRequest = nil
        }
        let firstStarted = expectation(description: "Initial schedule request started")
        DeferredScheduleURLProtocol.onRequest = { firstStarted.fulfill() }
        let first = Task { await model.load(locale: "en-us") }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectation(description: "Filtered schedule request started")
        DeferredScheduleURLProtocol.onRequest = { secondStarted.fulfill() }
        var filters = ServerPublicScheduleFilters()
        filters.sectionCode = "MATH101.01"
        let second = Task { await model.apply(filters, locale: "en-us") }
        await fulfillment(of: [secondStarted], timeout: 2)
        try DeferredScheduleURLProtocol.requests[1].complete(page([schedule(2)]))
        await second.value
        try DeferredScheduleURLProtocol.requests[0].complete(page([schedule(1)]))
        await first.value
        XCTAssertEqual(model.schedules.map(\.id), [2])
        XCTAssertEqual(model.filters.sectionCode, "MATH101.01")
        XCTAssertFalse(model.isLoading)
    }

    private func schedule(_ id: Int) -> [String: Any] {
        let teacher: [String: Any] = ["id": 3, "nameCn": "同名教师", "nameEn": "Same Name", "code": "T003"]
        let other: [String: Any] = ["id": 4, "nameCn": "同名教师", "nameEn": "Same Name", "code": "T004"]
        let unknown: [String: Any] = ["id": 5, "nameCn": "同名教师", "nameEn": "Same Name", "code": "T005"]
        return [
            "id": id, "date": "2026-10-26", "weekday": 1, "startTime": 815, "endTime": 945,
            "teachers": [teacher, other, unknown],
            "teacherParticipations": [
                ["teacher": teacher, "periods": 1.5, "exerciseClass": true],
                ["teacher": other, "periods": 2.5, "exerciseClass": false],
                ["teacher": unknown, "periods": NSNull(), "exerciseClass": NSNull()],
            ],
            "section": ["id": 7, "jwId": 42, "code": "MATH101.01"],
            "room": ["id": 6, "namePrimary": "Room 2201"],
        ]
    }

    private func page(_ rows: [[String: Any]], number: Int = 1, total: Int = 1) -> [String: Any] {
        ["data": rows, "pagination": ["page": number, "pageSize": 30, "total": total, "totalPages": (total + 29) / 30]]
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }
}

private final class DeferredScheduleURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredScheduleURLProtocol] = []
    @MainActor static var onRequest: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @MainActor in Self.requests.append(self); Self.onRequest?() }
    }
    override func stopLoading() {}

    @MainActor
    func complete(_ json: [String: Any]) throws {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
}

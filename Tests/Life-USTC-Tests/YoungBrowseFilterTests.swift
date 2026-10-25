import XCTest
@testable import Life_USTC

final class YoungBrowseFilterTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        client = ServerClient(configuration: .init(baseURL: URL(string: "https://young.example")!,
                                                   session: MockURLProtocol.mockSession(), tokenStore: MockTokenStore()))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testUnknownDatesKeepEveryScalarFilterOnEveryPage() async throws {
        let filters = YoungBrowseFilters(search: "  Science + Art  ", category: "  单次, 系列  ",
                                         module: "智", activityLevel: "校级", organizerId: "org/science",
                                         active: false, basis: .registration,
                                         dateFrom: ISO8601DateFormatter().date(from: "2026-10-24T16:30:00Z"),
                                         dateTo: ISO8601DateFormatter().date(from: "2026-10-31T16:30:00Z"))
        let model = YoungEventsViewModel(dateUnknown: true, filters: filters, client: client)
        MockURLProtocol.requestHandler = { request in
            let query = try self.query(request)
            let page = Int(query["page"]!)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: self.page([self.event("event-\(page)")],
                                                                                   page: page, totalPages: 2)))
        }

        await model.load()

        XCTAssertNil(model.error)
        XCTAssertEqual(model.events.map(\.youngId), ["event-1", "event-2"])
        XCTAssertEqual(model.unknownDateCount, 2)
        let requests = MockURLProtocol.capturedRequests
        XCTAssertEqual(requests.count, 2)
        for (index, request) in requests.enumerated() {
            XCTAssertEqual(try query(request), ["dateUnknown": "true", "active": "false", "category": "单次, 系列",
                                               "module": "智", "activityLevel": "校级", "search": "Science + Art",
                                               "organizerId": "org/science", "timeBasis": "registration",
                                               "page": "\(index + 1)", "pageSize": "100"])
            XCTAssertEqual(request.url?.path, "/api/catalog/young-events")
        }
        XCTAssertEqual(model.filters, filters)
    }

    @MainActor
    func testDatedListSendsShanghaiBoundsOnEveryPage() async throws {
        let filters = YoungBrowseFilters(module: "智", basis: .registration,
                                         dateFrom: ISO8601DateFormatter().date(from: "2026-10-24T16:30:00Z"),
                                         dateTo: ISO8601DateFormatter().date(from: "2026-10-31T16:30:00Z"))
        let model = YoungEventsViewModel(filters: filters, client: client)
        MockURLProtocol.requestHandler = { request in
            let query = try self.query(request)
            let page = Int(query["page"]!)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try JSONSerialization.data(withJSONObject: self.page([self.event("event-\(page)")],
                                                                                   page: page, totalPages: 2)))
        }
        await model.load()
        XCTAssertNil(model.error)
        XCTAssertEqual(model.events.count, 2)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        for request in MockURLProtocol.capturedRequests {
            let query = try query(request)
            XCTAssertEqual(query["dateFrom"], "2026-10-25")
            XCTAssertEqual(query["dateTo"], "2026-11-01")
            XCTAssertEqual(query["module"], "智")
            XCTAssertEqual(query["timeBasis"], "registration")
            XCTAssertNil(query["dateUnknown"])
        }
    }

    @MainActor
    func testFilterFailureRetriesWithoutLosingSearchOrSelections() async throws {
        let filters = YoungBrowseFilters(search: "Science", category: "Campus workshop", module: "智", active: true)
        let model = YoungEventsViewModel(filters: filters, client: client)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertEqual(model.filters, filters)

        MockURLProtocol.stubJSON(page([event("matching")]))
        await model.load()
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.events.map(\.youngId), ["matching"])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        XCTAssertEqual(try query(MockURLProtocol.capturedRequests[0]), try query(MockURLProtocol.capturedRequests[1]))
    }

    @MainActor
    func testEmptyFiltersOmitWhitespaceAndPreviousSelections() async throws {
        let model = YoungEventsViewModel(filters: .init(search: "Science", category: "Campus workshop", module: "智",
                                                        activityLevel: "校级", organizerId: "org", active: false), client: client)
        MockURLProtocol.stubJSON(page([event("old")]))
        await model.load()
        XCTAssertEqual(model.events.count, 1)
        model.filters = .init(search: "  \n ", category: "\t")
        MockURLProtocol.stubJSON(page([]))
        await model.load()
        XCTAssertNil(model.error)
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertFalse(model.filters.hasSelections)
        XCTAssertEqual(try query(XCTUnwrap(MockURLProtocol.capturedRequests.last)),
                       ["timeBasis": "activity", "page": "1", "pageSize": "100"])
    }

    func testClientPreservesUnrecognizedModuleAndLevelAsScalarValues() async throws {
        MockURLProtocol.stubJSON(page([event("future")]))
        let events = try await client.fetchYoungEvents(.init(module: "未来, 模块", activityLevel: "国际级"))
        XCTAssertEqual(events.first?.module, "未来模块")
        XCTAssertEqual(events.first?.activityLevel, "国际级")
        let query = try query(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        XCTAssertEqual(query["module"], "未来, 模块")
        XCTAssertEqual(query["activityLevel"], "国际级")
        XCTAssertNil(query["active"])
    }

    private func query(_ request: URLRequest) throws -> [String: String] {
        var components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%20")
        let items = try XCTUnwrap(components.queryItems)
        return try Dictionary(uniqueKeysWithValues: items.map { ($0.name, try XCTUnwrap($0.value)) })
    }

    private func event(_ id: String) -> [String: Any] {
        ["youngId": id, "name": id, "isActive": false, "module": "未来模块", "activityLevel": "国际级",
         "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
         "signupDepartmentIds": [], "allowedAttachmentTypes": []]
    }

    private func page(_ events: [[String: Any]], page: Int = 1, totalPages: Int = 1) -> [String: Any] {
        ["data": events, "pagination": ["page": page, "pageSize": 100, "total": events.count * totalPages,
                                        "totalPages": totalPages],
         "meta": ["unknownDateCount": events.count * totalPages, "source": ["status": "fresh"]]]
    }
}

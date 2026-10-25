import XCTest
@testable import Life_USTC

final class YoungIncrementalLoadingTests: XCTestCase {
    @MainActor
    func testListPublishesFirstBatchBeforeSecondRequestCompletes() async throws {
        let model = YoungEventsViewModel(client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        let firstStarted = expectation(description: "First activity page requested")
        DeferredYoungPageURLProtocol.onRequest = { firstStarted.fulfill() }
        let load = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectation(description: "Second activity page requested")
        DeferredYoungPageURLProtocol.onRequest = { secondStarted.fulfill() }
        try DeferredYoungPageURLProtocol.requests[0].complete(page(1))
        await fulfillment(of: [secondStarted], timeout: 2)

        XCTAssertTrue(model.isLoading)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.events.count, 100, "The accepted first page must be visible while page two is pending")

        try DeferredYoungPageURLProtocol.requests[1].complete(page(2))
        await load.value
        XCTAssertEqual(model.events.map(\.youngId), (1...101).map { "activity-\($0)" })
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.error)
        XCTAssertTrue(model.pages.isComplete)
    }

    @MainActor
    func testCalendarPublishesFirstBatchBeforeSecondRequestCompletes() async throws {
        let model = YoungActivityCalendarModel(client: makeClient())
        model.mode = .day
        model.basis = .registration
        model.referenceDate = YoungCalendarDate.dateFormatter.date(from: "2026-10-25")!
        defer { DeferredYoungPageURLProtocol.reset() }
        let firstStarted = expectRequest("First calendar page")
        let load = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectRequest("Second calendar page")
        try DeferredYoungPageURLProtocol.requests[0].complete(page(1))
        await fulfillment(of: [secondStarted], timeout: 2)

        XCTAssertEqual(model.events.count, 100)
        XCTAssertTrue(model.isLoading)
        XCTAssertFalse(model.pages.isComplete)
        for request in DeferredYoungPageURLProtocol.requests {
            XCTAssertEqual(query(request), ["dateFrom": "2026-10-25", "dateTo": "2026-10-25",
                                            "timeBasis": "registration", "pageSize": "100",
                                            "page": query(request)["page"]!])
        }
        try DeferredYoungPageURLProtocol.requests[1].complete(page(2))
        await load.value
        XCTAssertEqual(model.events.count, 101)
        XCTAssertTrue(model.pages.isComplete)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.error)
    }

    @MainActor
    func testListKeepsFirstBatchAndContinuesOnlyTheFailedPage() async throws {
        let model = YoungEventsViewModel(filters: .init(search: "workshop", module: "智"), client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        try await verifyContinuation(pages: model.pages, load: { await model.load() })
        for request in DeferredYoungPageURLProtocol.requests {
            XCTAssertEqual(query(request)["search"], "workshop")
            XCTAssertEqual(query(request)["module"], "智")
        }
    }

    @MainActor
    func testCalendarKeepsFirstBatchAndContinuesOnlyTheFailedPage() async throws {
        let model = YoungActivityCalendarModel(client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        try await verifyContinuation(pages: model.pages, load: { await model.load() })
        let requests = DeferredYoungPageURLProtocol.requests
        XCTAssertEqual(query(requests[1]), query(requests[2]))
    }

    @MainActor
    func testNewFiltersClearReceivedRowsAndIgnoreThePreviousPendingPage() async throws {
        let model = YoungEventsViewModel(filters: .init(search: "old"), client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        let firstStarted = expectRequest("Original first page")
        let original = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectRequest("Original second page")
        try DeferredYoungPageURLProtocol.requests[0].complete(page(1))
        await fulfillment(of: [secondStarted], timeout: 2)
        XCTAssertEqual(model.events.count, 100)

        model.filters.search = "new"
        let replacementStarted = expectRequest("Replacement first page")
        let replacement = Task { await model.load() }
        await fulfillment(of: [replacementStarted], timeout: 2)
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertNil(model.source)
        XCTAssertEqual(model.unknownDateCount, 0)
        XCTAssertFalse(model.pages.isComplete)
        try DeferredYoungPageURLProtocol.requests[1].complete(page(2))
        await original.value
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertTrue(model.isLoading)

        let request = DeferredYoungPageURLProtocol.requests[2]
        XCTAssertEqual(query(request)["search"], "new")
        XCTAssertEqual(query(request)["page"], "1")
        try request.complete(page(1, totalPages: 1, prefix: "replacement"))
        await replacement.value
        XCTAssertEqual(model.events.count, 100)
        XCTAssertTrue(model.events.allSatisfy { $0.youngId.hasPrefix("replacement-") })
        XCTAssertTrue(model.pages.isComplete)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testCancellationKeepsAcceptedRowsWithoutPublishingAnError() async throws {
        let model = YoungEventsViewModel(client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        let firstStarted = expectRequest("First page before cancellation")
        let load = Task { await model.load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectRequest("Pending page before cancellation")
        try DeferredYoungPageURLProtocol.requests[0].complete(page(1))
        await fulfillment(of: [secondStarted], timeout: 2)
        load.cancel()
        await load.value
        XCTAssertEqual(model.events.count, 100)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.pages.isComplete)
        XCTAssertEqual(DeferredYoungPageURLProtocol.requests.count, 2)
    }

    @MainActor
    func testEmptyCalendarIsCompleteOnlyAfterTheResponseArrives() async throws {
        let model = YoungActivityCalendarModel(client: makeClient())
        defer { DeferredYoungPageURLProtocol.reset() }
        let started = expectRequest("Empty calendar request")
        let load = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertFalse(model.pages.isComplete)
        var empty = page(1, totalPages: 0)
        empty["data"] = [[String: Any]]()
        empty["pagination"] = ["page": 1, "pageSize": 100, "total": 0, "totalPages": 0]
        try DeferredYoungPageURLProtocol.requests[0].complete(empty)
        await load.value
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertTrue(model.pages.isComplete)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.error)
    }

    @MainActor
    private func verifyContinuation(pages: YoungEventsPageModel, load: @escaping () async -> Void) async throws {
        let firstStarted = expectRequest("First page before interruption")
        let firstLoad = Task { await load() }
        await fulfillment(of: [firstStarted], timeout: 2)
        let secondStarted = expectRequest("Second page before interruption")
        try DeferredYoungPageURLProtocol.requests[0].complete(page(1))
        await fulfillment(of: [secondStarted], timeout: 2)
        try DeferredYoungPageURLProtocol.requests[1].complete(["error": "Unavailable"], status: 503)
        await firstLoad.value
        XCTAssertEqual(pages.events.count, 100)
        XCTAssertFalse(pages.isLoading)
        XCTAssertFalse(pages.isComplete)
        XCTAssertNotNil(pages.error)
        XCTAssertEqual(pages.unknownDateCount, 3)
        XCTAssertEqual(pages.source?.status, "fresh")

        let continued = expectRequest("Continue unfinished page")
        let continuation = Task { await pages.continueLoading() }
        await fulfillment(of: [continued], timeout: 2)
        XCTAssertEqual(pages.events.count, 100)
        XCTAssertTrue(pages.isLoading)
        XCTAssertNil(pages.error)
        XCTAssertEqual(DeferredYoungPageURLProtocol.requests.map { query($0)["page"] }, ["1", "2", "2"])
        var final = page(2)
        final["meta"] = ["unknownDateCount": 9, "source": ["status": "stale"]]
        try DeferredYoungPageURLProtocol.requests[2].complete(final)
        await continuation.value
        XCTAssertEqual(pages.events.map(\.youngId), (1...101).map { "activity-\($0)" })
        XCTAssertTrue(pages.isComplete)
        XCTAssertFalse(pages.isLoading)
        XCTAssertNil(pages.error)
        XCTAssertEqual(pages.unknownDateCount, 3)
        XCTAssertEqual(pages.source?.status, "fresh")
    }

    @MainActor
    private func expectRequest(_ description: String) -> XCTestExpectation {
        let started = expectation(description: description)
        DeferredYoungPageURLProtocol.onRequest = { started.fulfill() }
        return started
    }

    private func makeClient() -> ServerClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredYoungPageURLProtocol.self]
        return ServerClient(configuration: .init(
            baseURL: URL(string: "https://young.example")!,
            session: URLSession(configuration: configuration), tokenStore: MockTokenStore()
        ))
    }

    private func query(_ request: DeferredYoungPageURLProtocol) -> [String: String] {
        let components = URLComponents(url: request.request.url!, resolvingAgainstBaseURL: false)!
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func page(_ number: Int, totalPages: Int = 2, prefix: String = "activity") -> [String: Any] {
        let indices = number == 1 ? Array(1...100) : [101]
        let events: [[String: Any]] = indices.map { index in
            ["youngId": "\(prefix)-\(index)", "name": "Activity \(index)", "isActive": true,
             "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
             "signupDepartmentIds": [], "allowedAttachmentTypes": []]
        }
        return ["data": events,
                "pagination": ["page": number, "pageSize": 100, "total": totalPages == 2 ? 101 : 100, "totalPages": totalPages],
                "meta": ["unknownDateCount": 3, "source": ["status": "fresh"]]]
    }
}

private final class DeferredYoungPageURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredYoungPageURLProtocol] = []
    @MainActor static var onRequest: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @MainActor in Self.requests.append(self); Self.onRequest?() }
    }
    override func stopLoading() {}

    @MainActor
    static func reset() {
        requests = []
        onRequest = nil
    }

    @MainActor
    func complete(_ json: [String: Any], status: Int = 200) throws {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
}

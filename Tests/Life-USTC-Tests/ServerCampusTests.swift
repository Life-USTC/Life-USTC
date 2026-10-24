import XCTest
@testable import Life_USTC

final class ServerCampusTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "campus-owner"
        client = ServerClient(configuration: .init(baseURL: URL(string: "https://campus.example")!,
                                                  session: MockURLProtocol.mockSession(), tokenStore: tokens))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testPublicCampusEndpointsUseCanonicalLocationsAndCatalogSearchScope() {
        let cases: [(ServerEndpoint, String, [String: String])] = [
            (.campusLinks(locale: "en-us"), "/api/catalog/links", ["locale": "en-us"]),
            (.campusWeather(.main), "/api/catalog/weather", ["locationKey": "ustc-main"]),
            (.campusWeather(.gaoxin), "/api/catalog/weather", ["locationKey": "ustc-gaoxin"]),
            (.campusSearch(query: "space & 中国", locale: "zh-cn"), "/api/search",
             ["q": "space & 中国", "scope": "catalog", "limit": "25", "locale": "zh-cn"]),
            (.roomMap(code: "ＧＴ-101"), "/api/catalog/rooms/ＧＴ-101/map", [:]),
        ]
        for (endpoint, path, query) in cases {
            let request = endpoint.buildURLRequest(baseURL: client.baseURL)
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, path)
            XCTAssertEqual(queryItems(request), query)
        }
    }

    func testBusRoutesAndNextCarryExplicitStopsVersionAndDayWithoutAmbientPreferences() {
        let query = ServerBusNextQuery(originCampusId: 2, destinationCampusId: 3, dayType: "sunday", includeDeparted: true,
                                       versionKey: "past-version", atTime: "2035-09-15T10:30:00+08:00", locale: "en-us")
        let next = ServerEndpoint.busNext(query).buildURLRequest(baseURL: client.baseURL)
        XCTAssertEqual(next.url?.path, "/api/catalog/bus/next")
        XCTAssertEqual(queryItems(next), ["originCampusId": "2", "destinationCampusId": "3", "dayType": "sunday",
                                         "includeDeparted": "true", "limit": "50", "versionKey": "past-version",
                                         "atTime": "2035-09-15T10:30:00+08:00", "locale": "en-us"])
        let routes = ServerEndpoint.busRoutes(origin: 2, destination: 3, versionKey: nil, locale: "zh-cn")
            .buildURLRequest(baseURL: client.baseURL)
        XCTAssertEqual(queryItems(routes), ["originCampusId": "2", "destinationCampusId": "3", "locale": "zh-cn"])
    }

    func testPreferenceClearEncodesNullAndFalseRatherThanOmittingValues() throws {
        let preference = ServerBusPreference(preferredOriginCampusId: nil, preferredDestinationCampusId: nil, showDepartedTrips: false)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preference)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["preferredOriginCampusId", "preferredDestinationCampusId", "showDepartedTrips"])
        XCTAssertTrue(body["preferredOriginCampusId"] is NSNull)
        XCTAssertTrue(body["preferredDestinationCampusId"] is NSNull)
        XCTAssertEqual(body["showDepartedTrips"] as? Bool, false)
        XCTAssertEqual(ServerEndpoint.setBusPreferences(preference).path, "/api/workspace/bus-preferences")
        XCTAssertEqual(ServerEndpoint.setBusPreferences(preference).method, "POST")
    }

    func testPinUsesJsonBatchAndReturnsTheServerEvictionOrder() async throws {
        MockURLProtocol.stubJSON(pins(["b", "c", "d", "new"]))
        let result = try await client.setLinkPinned(slug: "new", pinned: true, expectedRevision: client.sessionRevision)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/workspace/link-pins/batch")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let items = try body(request)["items"] as? [[String: String]]
        XCTAssertEqual(items, [["slug": "new", "action": "pin"]])
        XCTAssertEqual(result.pinnedSlugs, ["b", "c", "d", "new"])
    }

    func testCampusLinkSearchUsesEveryTokenIncludingTonelessPinyin() throws {
        let link = try decode(ServerCampusLink.self, link())
        XCTAssertTrue(link.matches("  JIAOWU   中国  "))
        XCTAssertTrue(link.matches("ACADEMIC example"))
        XCTAssertTrue(link.matches(""))
        XCTAssertFalse(link.matches("jiaowu unmatched"))
    }

    @MainActor
    func testFailedPinReadKeepsPublicLinksUsableAndPreventsWritesUntilRetry() async {
        var unavailable = true
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/catalog/links" { return try self.response(request, ["links": [self.link()]]) }
            return try self.response(request, unavailable ? ["error": "Unavailable"] : self.pins(["academic"]), status: unavailable ? 503 : 200)
        }
        let model = ServerCampusLinksModel(client: client)
        await model.load(locale: "en-us")
        XCTAssertEqual(model.links.count, 1)
        XCTAssertFalse(model.canPin)
        XCTAssertNotNil(model.pinError)
        await model.setPinned(slug: "academic", pinned: false)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        unavailable = false
        await model.loadPins()
        XCTAssertTrue(model.canPin)
        XCTAssertEqual(model.pinnedSlugs, ["academic"])
    }

    @MainActor
    func testFailedPinWriteRetainsConfirmedPinsAndRetriesExplicitIntent() async {
        var fail = true
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/catalog/links" { return try self.response(request, ["links": [self.link()]]) }
            if request.httpMethod == "GET" { return try self.response(request, self.pins(["a", "b", "c", "d"])) }
            return try self.response(request, fail ? ["error": "Unavailable"] : self.pins(["b", "c", "d", "academic"]), status: fail ? 503 : 200)
        }
        let model = ServerCampusLinksModel(client: client)
        await model.load(locale: "en-us")
        await model.setPinned(slug: "academic", pinned: true)
        XCTAssertEqual(model.pinnedSlugs, ["a", "b", "c", "d"])
        XCTAssertTrue(model.canRetryPin)
        fail = false
        await model.retryPin()
        XCTAssertEqual(model.pinnedSlugs, ["b", "c", "d", "academic"])
        XCTAssertNil(model.pinError)
        XCTAssertFalse(model.canRetryPin)
    }

    @MainActor
    func testOldAccountPinsCannotWriteAfterSessionChanges() async {
        MockURLProtocol.requestHandler = { request in
            try self.response(request, request.url?.path == "/api/catalog/links" ? ["links": [self.link()]] : self.pins(["academic"]))
        }
        let model = ServerCampusLinksModel(client: client)
        await model.load(locale: "en-us")
        client.clearTokens()
        client.accessToken = "next-owner"
        XCTAssertTrue(model.pinnedSlugs.isEmpty)
        XCTAssertFalse(model.canPin)
        await model.setPinned(slug: "academic", pinned: false)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testStopTimeEstimatesMatchServerBoundsAndRounding() throws {
        let trip = try decode(ServerBusTrip.self, trip(times: [600, nil, 631]))
        XCTAssertEqual(ServerBusStopClock.at(campusID: 1, trip: trip), .init(minutes: 600, estimated: false))
        XCTAssertEqual(ServerBusStopClock.at(campusID: 2, trip: trip), .init(minutes: 616, estimated: true))
        for times: [Int?] in [[nil, nil, 631], [600, nil, nil], [1400, nil, 20], [nil, nil, nil]] {
            let unknown = try decode(ServerBusTrip.self, self.trip(times: times))
            XCTAssertNil(ServerBusStopClock.at(campusID: 2, trip: unknown))
        }
    }

    @MainActor
    func testBusPreferenceReadFailureNeverWritesDefaultsAndRetryKeepsAnExplicitSelection() async {
        var fail = true
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/catalog/bus" { return try self.response(request, self.timetable()) }
            return try self.response(request, fail ? ["error": "Unavailable"] : ["preference": self.preference(origin: 2)], status: fail ? 503 : 200)
        }
        let model = ServerBusPlannerModel(client: client)
        await model.load()
        model.selectOrigin(1)
        XCTAssertFalse(model.canSavePreference)
        await model.savePreference()
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.httpMethod == "POST" })
        fail = false
        await model.loadPreference()
        XCTAssertEqual(model.origin, 1, "Resolving saved preferences must not overwrite the in-progress explicit route choice")
        XCTAssertTrue(model.canSavePreference)
    }

    @MainActor
    func testBusSavedPreferenceSuppliesExplicitStopsAndWritesOnlyWhenRequested() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/catalog/bus" { return try self.response(request, self.timetable()) }
            if request.httpMethod == "POST" {
                XCTAssertEqual(try self.body(request)["showDepartedTrips"] as? Bool, false)
                return try self.response(request, ["preference": self.preference(origin: 2, showDeparted: false)])
            }
            return try self.response(request, ["preference": self.preference(origin: 2, showDeparted: true)])
        }
        let model = ServerBusPlannerModel(client: client)
        await model.load()
        XCTAssertEqual(model.origin, 2)
        XCTAssertEqual(model.destination, 3)
        XCTAssertTrue(model.showDeparted)
        XCTAssertFalse(model.canSavePreference)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        model.setShowDeparted(false)
        await model.savePreference()
        XCTAssertFalse(model.canSavePreference)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.httpMethod, "POST")
    }

    @MainActor
    func testInvalidBusSelectionClearsLoadingBeforePreviousRequestsFinish() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredBusURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = ServerClient(configuration: .init(baseURL: URL(string: "https://campus.example")!,
                                                      session: session, tokenStore: MockTokenStore()))
        defer {
            session.invalidateAndCancel()
            DeferredBusURLProtocol.requests = []
            DeferredBusURLProtocol.onRequest = nil
        }
        let invalidDestinations: [Int?] = [1, nil]
        for destination in invalidDestinations {
            DeferredBusURLProtocol.requests = []
            let started = expectation(description: "Both departure requests started")
            started.expectedFulfillmentCount = 2
            DeferredBusURLProtocol.onRequest = { started.fulfill() }
            let model = ServerBusPlannerModel(client: client)
            model.selectOrigin(1)
            model.selectDestination(2)
            let previous = Task { await model.refreshDepartures(locale: "en-us") }
            defer { previous.cancel() }
            await fulfillment(of: [started], timeout: 2)
            DeferredBusURLProtocol.onRequest = nil
            XCTAssertTrue(model.isLoadingDepartures)

            model.selectDestination(destination)
            await model.refreshDepartures(locale: "en-us")
            XCTAssertFalse(model.isLoadingDepartures, "Invalid selection must stop loading immediately")
            XCTAssertEqual(DeferredBusURLProtocol.requests.count, 2)
            XCTAssertNil(model.next)
            XCTAssertNil(model.routeResult)

            for request in DeferredBusURLProtocol.requests {
                let body: [String: Any] = request.request.url?.path == "/api/catalog/bus/routes"
                    ? ["total": 0, "routes": []]
                    : ["atTime": "2035-09-15T10:30:00+08:00", "dayType": "weekday", "totalRoutes": 0, "departures": []]
                try request.complete(body)
            }
            await previous.value
            XCTAssertFalse(model.isLoadingDepartures, "The previous query must not leave loading active")
            XCTAssertNil(model.next)
            XCTAssertNil(model.routeResult)
        }
    }

    func testWeatherRetainsAbsentObservationAndUnknownTemperature() throws {
        let snapshot: [String: Any] = ["location": ["key": "ustc-main", "name": "Main", "adcode": "340100"],
            "fetchedAt": "2035-09-15T10:30:00+08:00", "providers": ["open-meteo"],
            "current": ["source": "open-meteo", "temperature": NSNull(), "condition": ["text": "Unavailable", "icon": "unknown"]],
            "hourly": [], "daily": [], "alerts": [], "extensions": [:]]
        let value = try decode(ServerWeatherSnapshot.self, snapshot)
        XCTAssertNil(value.current.temperature)
        XCTAssertNil(value.current.observedAt)
        XCTAssertEqual(value.current.source, "open-meteo")
        XCTAssertTrue(value.hourly.isEmpty)
    }

    func testRoomOverviewDoesNotClaimAHighlightedRoom() throws {
        let overview = try decode(ServerRoomMap.self, ["code": "GT-101", "building": NSNull(), "floor": NSNull(),
            "status": "overview", "imageUrl": "https://static.example/floor.png", "sourceImageUrl": "https://static.example/floor.png"])
        XCTAssertEqual(overview.status, .overview)
        XCTAssertNil(overview.building)
        XCTAssertNil(overview.floor)
    }

    @MainActor
    func testFailedPinRefreshKeepsConfirmedPinsButRequiresReadRetryBeforeWriting() async {
        var fail = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/api/catalog/links" { return try self.response(request, ["links": [self.link()]]) }
            return try self.response(request, fail ? ["error": "Unavailable"] : self.pins(["academic"]), status: fail ? 503 : 200)
        }
        let model = ServerCampusLinksModel(client: client)
        await model.load(locale: "en-us")
        XCTAssertTrue(model.canPin)
        fail = true
        await model.loadPins()
        XCTAssertEqual(model.pinnedSlugs, ["academic"])
        XCTAssertFalse(model.canPin)
        await model.setPinned(slug: "academic", pinned: false)
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.httpMethod == "POST" })
    }

    @MainActor
    func testCompleteTimetableDoesNotUseNextDepartureResultLimit() async {
        var full = timetable()
        full["trips"] = (0..<75).map { index in
            var value = trip(times: [600 + index, nil, 630 + index])
            value["id"] = index + 1
            value["position"] = index
            return value
        }
        MockURLProtocol.requestHandler = { request in
            try self.response(request, request.url?.path == "/api/catalog/bus" ? full : ["preference": self.preference(origin: 1)])
        }
        let model = ServerBusPlannerModel(client: client)
        await model.load()
        model.dayType = "weekday"
        model.setShowDeparted(true)
        XCTAssertEqual(model.trips(for: 1).count, 75)
        XCTAssertEqual(model.trips(for: 1).last?.id, 75)
    }

    @MainActor
    func testRoomCodeUsesServerNormalizationAndRejectsInvalidInputWithoutRequest() async {
        XCTAssertEqual(ServerRoomMapModel.normalizedCode("  ｇｔ-１０１  "), "GT-101")
        XCTAssertEqual(ServerRoomMapModel.normalizedCode("3a204"), "3A204")
        for invalid in ["", "../3A204", "A--1", "-A1", "A1-", String(repeating: "a", count: 65)] {
            XCTAssertNil(ServerRoomMapModel.normalizedCode(invalid))
        }
        let model = ServerRoomMapModel(client: client)
        await model.lookup("../3A204")
        XCTAssertNotNil(model.error)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    @MainActor
    func testRoomLookupRetriesTransportFailureAndRetainsServerOverviewStatus() async {
        let model = ServerRoomMapModel(client: client)
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.lookup("3a204")
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.result)
        MockURLProtocol.stubJSON(["code": "3A204", "status": "overview", "imageUrl": "/map.png"])
        await model.lookup("3a204")
        XCTAssertEqual(model.result?.code, "3A204")
        XCTAssertEqual(model.result?.status, .overview)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path, "/api/catalog/rooms/3A204/map")
        XCTAssertNil(model.error)
    }

    @MainActor
    func testSearchHonorsQueryBoundsAndUsesPublicCatalogScope() async throws {
        let model = ServerCampusSearchModel(client: client)
        for invalid in [" a ", "", String(repeating: "x", count: 201)] {
            await model.search(invalid, locale: "en-us")
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        MockURLProtocol.stubJSON(["query": "Computer Science", "groups": []])
        await model.search("  Computer Science  ", locale: "en-us")
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(queryItems(request)["q"], "Computer Science")
        XCTAssertEqual(queryItems(request)["scope"], "catalog")
        XCTAssertEqual(model.result?.query, "Computer Science")
        await model.search("x", locale: "en-us")
        XCTAssertNil(model.result)
        XCTAssertFalse(model.isLoading)
    }

    func testSearchUsesNativeCourseSectionAndTeacherIdentifiers() throws {
        let cases: [(String, String, ServerCampusSearchDestination)] = [
            ("courses", "course:123", .course(123)), ("sections", "section:456", .section(456)),
            ("teachers", "teacher:789", .teacher(789)),
            ("links", "link:academic", .external(URL(string: "https://academic.example")!)),
        ]
        for (group, id, expected) in cases {
            let item = try decode(ServerGlobalSearchResponse.Item.self,
                                  ["id": id, "title": "Result", "href": "https://academic.example"])
            XCTAssertEqual(ServerCampusSearchDestination(item: item, group: group), expected)
        }
    }

    private func pins(_ slugs: [String]) -> [String: Any] { ["pinnedSlugs": slugs, "maxPinnedLinks": 4, "error": NSNull()] }
    private func link() -> [String: Any] {
        ["slug": "academic", "title": "中国 Academic", "url": "https://academic.example", "description": "教务", "titlePinyin": "zhongguo",
         "descriptionPinyin": "jiaowu", "category": "academic", "icon": "book-open", "group": "study", "locale": "en-us"]
    }
    private func campus(_ id: Int) -> [String: Any] {
        ["id": id, "nameCn": "Campus \(id)", "nameEn": "Campus \(id)", "latitude": 31.8, "longitude": 117.2]
    }
    private func trip(times: [Int?]) -> [String: Any] {
        ["id": 1, "routeId": 1, "dayType": "weekday", "position": 0,
         "stopTimes": times.enumerated().map { index, minutes in
             ["stopOrder": index, "campusId": index + 1, "minutesSinceMidnight": minutes as Any? ?? NSNull()] as [String: Any]
         }]
    }
    private func timetable() -> [String: Any] {
        ["locale": "en-us", "fetchedAt": "2035-09-15T10:30:00+08:00", "version": NSNull(), "availableVersions": [],
         "campuses": [campus(1), campus(2), campus(3)], "routes": [["id": 1, "nameCn": "Route", "stops": (1...3).map { ["stopOrder": $0, "campus": campus($0)] }]],
         "trips": [trip(times: [600, nil, 631])], "notice": NSNull()]
    }
    private func preference(origin: Int, showDeparted: Bool = false) -> [String: Any] {
        ["preferredOriginCampusId": origin, "preferredDestinationCampusId": 3, "showDepartedTrips": showDeparted]
    }
    private func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        try client.decoder.decode(type, from: JSONSerialization.data(withJSONObject: object))
    }
    private func queryItems(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let body = request.httpBody { data = body }
        else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var bytes = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                bytes.append(buffer, count: count)
            }
            data = bytes
        } else { data = Data() }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    private func response(_ request: URLRequest, _ object: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
         try JSONSerialization.data(withJSONObject: object))
    }
}

private final class DeferredBusURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredBusURLProtocol] = []
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

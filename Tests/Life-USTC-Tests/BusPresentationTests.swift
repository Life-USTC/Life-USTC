import XCTest
@testable import Life_USTC

final class BusPresentationTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testKnownAdjacentTimesGiveTheSameEstimatedProgressAsTheServerMap() {
        let active = ServerBusActiveTrip.trips([trip(times: [480, 540])], at: date("2026-10-23T00:30:00Z"))
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.status, .enRoute)
        XCTAssertEqual(active.first?.progress, 0.5)
        let point = active.first?.coordinate(in: route())
        XCTAssertEqual(point?.latitude, 31.5)
        XCTAssertEqual(point?.longitude, 117.5)
    }

    func testUnknownIntermediateTimeDoesNotCreateAVehiclePosition() {
        let active = ServerBusActiveTrip.trips([trip(times: [480, nil, 540])], at: date("2026-10-23T00:30:00Z"))
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.status, .enRoute)
        XCTAssertNil(active.first?.progress)
        XCTAssertNil(active.first?.coordinate(in: route()))
    }

    func testUpcomingTripsUseTheFirstStationOnlyWithinOneHourAndOnTheCurrentDay() {
        let active = ServerBusActiveTrip.trips([trip(times: [540, 600]), trip(id: 2, times: [600, 660]),
                                                trip(id: 3, times: [540, 600], day: .saturday)],
                                               at: date("2026-10-23T00:30:00Z"))
        XCTAssertEqual(active.map(\.id), [1])
        XCTAssertEqual(active.first?.status, .departingSoon)
        XCTAssertEqual(active.first?.coordinate(in: route())?.latitude, 31)
        XCTAssertTrue(ServerBusActiveTrip.trips([trip(times: [480, 540])], at: date("2026-10-23T02:00:00Z")).isEmpty)
    }

    func testLocalRouteRequiresAForwardTraversableStopPair() {
        XCTAssertTrue(ServerRecentBusRoute(origin: 1, destination: 3).isTraversable(in: [route()]))
        XCTAssertFalse(ServerRecentBusRoute(origin: 3, destination: 1).isTraversable(in: [route()]))
        XCTAssertFalse(ServerRecentBusRoute(origin: 1, destination: 1).isTraversable(in: [route()]))
        XCTAssertFalse(ServerRecentBusRoute(origin: 99, destination: 2).isTraversable(in: [route()]))
    }

    @MainActor
    func testSignedInPreferencesWinWithoutOverwritingAnonymousRecentRoute() async throws {
        let suite = "bus-parity-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let recent = try JSONEncoder().encode(ServerRecentBusRoute(origin: 2, destination: 3))
        defaults.set(recent, forKey: ServerBusPlannerModel.recentRouteKey)
        let tokens = MockTokenStore()
        let client = ServerClient(configuration: .init(baseURL: URL(string: "https://bus.example")!,
                                                       session: MockURLProtocol.mockSession(), tokenStore: tokens))
        MockURLProtocol.requestHandler = { request in
            let body: Any
            if request.url?.path == "/api/catalog/bus" {
                body = ["locale": "en-us", "fetchedAt": "2026-10-23T00:00:00Z", "availableVersions": [],
                        "campuses": (1...3).map { self.campus($0) },
                        "routes": [["id": 1, "stops": (1...3).map { ["stopOrder": $0 - 1, "campus": self.campus($0)] }]], "trips": []]
            } else {
                XCTAssertEqual(request.url?.path, "/api/workspace/bus-preferences")
                body = ["preference": ["preferredOriginCampusId": 1, "preferredDestinationCampusId": 2, "showDepartedTrips": true]]
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
        let anonymous = ServerBusPlannerModel(client: client, defaults: defaults)
        await anonymous.load()
        XCTAssertEqual(anonymous.origin, 2)
        XCTAssertEqual(anonymous.destination, 3)
        tokens.accessToken = "bus-owner"
        let signedIn = ServerBusPlannerModel(client: client, defaults: defaults)
        await signedIn.load()
        XCTAssertEqual(signedIn.origin, 1)
        XCTAssertEqual(signedIn.destination, 2)
        XCTAssertTrue(signedIn.showDeparted)
        await signedIn.load()
        XCTAssertEqual(signedIn.origin, 1)
        XCTAssertEqual(signedIn.destination, 2)
        XCTAssertTrue(signedIn.showDeparted)
        signedIn.selectDestination(3)
        XCTAssertEqual(defaults.data(forKey: ServerBusPlannerModel.recentRouteKey), recent)

        tokens.clear()
        defaults.set(try JSONEncoder().encode(ServerRecentBusRoute(origin: 3, destination: 1)), forKey: ServerBusPlannerModel.recentRouteKey)
        let invalid = ServerBusPlannerModel(client: client, defaults: defaults)
        await invalid.load()
        XCTAssertEqual(invalid.origin, 1)
        XCTAssertEqual(invalid.destination, 3)
        invalid.selectDestination(2)
        XCTAssertEqual(try JSONDecoder().decode(ServerRecentBusRoute.self, from: defaults.data(forKey: ServerBusPlannerModel.recentRouteKey)!),
                       ServerRecentBusRoute(origin: 1, destination: 2))
    }

    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    private func campus(_ id: Int) -> [String: Any] {
        ["id": id, "nameCn": "校区\(id)", "latitude": Double(30 + id), "longitude": Double(116 + id)]
    }

    private func route() -> ServerBusRoute {
        .init(id: 1, nameCn: nil, nameEn: nil, descriptionPrimary: nil, descriptionSecondary: nil,
              stops: (1...3).map { .init(stopOrder: $0 - 1, campus: .init(id: $0, nameCn: "校区", nameEn: nil,
                                                                          latitude: Double(30 + $0), longitude: Double(116 + $0),
                                                                          namePrimary: nil, nameSecondary: nil)) })
    }

    private func trip(id: Int = 1, times: [Int?], day: ServerBusDayType = .weekday) -> ServerBusTrip {
        .init(id: id, routeId: 1, dayType: day, position: 0,
              stopTimes: times.enumerated().map { index, minutes in
                  .init(stopOrder: index, campusId: index + 1, campusName: nil, time: nil,
                        minutesSinceMidnight: minutes, isPassThrough: nil)
              }, departureTime: nil, departureMinutes: nil, arrivalTime: nil, arrivalMinutes: nil)
    }
}

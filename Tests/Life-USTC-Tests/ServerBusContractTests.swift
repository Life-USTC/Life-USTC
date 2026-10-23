import XCTest
@testable import Life_USTC

final class ServerBusContractTests: XCTestCase {
    func testCompleteTimetablePreservesDayTypesStopColumnsAndRouteOrder() throws {
        let campuses: [[String: Any]] = [
            ["id": 1, "nameCn": "东区", "latitude": 31.84, "longitude": 117.26],
            ["id": 2, "nameCn": "中区", "latitude": 31.83, "longitude": 117.25],
            ["id": 3, "nameCn": "西区", "latitude": 31.82, "longitude": 117.24],
        ]
        let stops: [[String: Any]] = [
            ["stopOrder": 2, "campus": campuses[2]],
            ["stopOrder": 0, "campus": campuses[0]],
            ["stopOrder": 1, "campus": campuses[1]],
        ]
        func trip(_ id: Int, _ day: String, _ position: Int, _ time: String) -> [String: Any] {
            [
                "id": id, "routeId": 7, "dayType": day, "position": position,
                "stopTimes": [
                    ["stopOrder": 2, "time": "19:20"],
                    ["stopOrder": 0, "time": time],
                    ["stopOrder": 1, "time": NSNull(), "isPassThrough": true],
                ],
            ]
        }
        let json: [String: Any] = [
            "campuses": campuses,
            "routes": [["id": 7, "stops": stops], ["id": 2, "stops": stops]],
            "trips": [trip(1, "weekday", 2, "19:00"), trip(2, "saturday", 1, "10:00"), trip(3, "sunday", 1, "11:00"), trip(4, "weekday", 1, "08:00")],
            "notice": ["message": "按公布时刻发车", "url": "https://example.com/timetable"],
        ]
        let response = try JSONDecoder().decode(ServerBusResponse.self, from: JSONSerialization.data(withJSONObject: json))
        let data = USTCBusData(serverResponse: response)

        XCTAssertEqual(data.routes.map(\.id), [7, 2])
        XCTAssertEqual(data.routes.first?.campuses.map(\.id), [1, 2, 3])
        XCTAssertEqual(data.campuses.first?.latitude, 31.84)
        XCTAssertEqual(data.schedules(for: .weekday).first?.time, [["08:00", nil, "19:20"], ["19:00", nil, "19:20"]])
        XCTAssertEqual(data.schedules(for: .saturday).first?.time.first?.first, "10:00")
        XCTAssertEqual(data.schedules(for: .sunday).first?.time.first?.first, "11:00")
        XCTAssertEqual(data.schedules(for: .sunday).last?.id, 2)
        XCTAssertEqual(data.schedules(for: .sunday).last?.time.count, 0)
        XCTAssertEqual(data.message?.message, "按公布时刻发车")
    }

    func testExistingStaticWeekendPayloadStillSupportsBothDays() throws {
        let json = """
        {"campuses":[],"routes":[],"weekday_routes":[],"weekend_routes":[{"id":1,"route":{"id":1,"campuses":[]},"time":[["10:00"]]}]}
        """
        let data = try JSONDecoder().decode(USTCBusData.self, from: Data(json.utf8))
        XCTAssertEqual(data.schedules(for: .saturday).first?.time, [["10:00"]])
        XCTAssertEqual(data.schedules(for: .sunday).first?.time, [["10:00"]])
    }

    func testMissingTimetableCannotSilentlyDecodeAsEmptySuccess() {
        XCTAssertThrowsError(try JSONDecoder().decode(ServerBusResponse.self, from: Data("{}".utf8)))
    }
}

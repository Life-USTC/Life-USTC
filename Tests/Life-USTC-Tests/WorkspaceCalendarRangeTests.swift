import XCTest
@testable import Life_USTC

final class WorkspaceCalendarRangeTests: XCTestCase {
    private func date(_ key: String) -> Date { YoungCalendarDate.dateFormatter.date(from: key)! }

    func testLeapYearFitsOneInclusiveRequestWindow() {
        let range = ServerCalendarRange(start: date("2024-01-01"), end: date("2024-12-31"))
        XCTAssertEqual(range.days.count, 366)
        XCTAssertEqual(range.requestWindows.count, 1)
        XCTAssertEqual(range.requestWindows[0].from, "2024-01-01")
        XCTAssertEqual(range.requestWindows[0].to, "2024-12-31")
    }

    func testLongSemesterUsesContiguousWindowsAtMost366Days() {
        let range = ServerCalendarRange(start: date("2024-01-01"), end: date("2025-01-02"))
        XCTAssertEqual(range.requestWindows.count, 2)
        XCTAssertEqual(range.requestWindows[0].to, "2024-12-31")
        XCTAssertEqual(range.requestWindows[1].from, "2025-01-01")
        XCTAssertEqual(range.requestWindows[1].to, "2025-01-02")
    }

    func testReversedRangeRetainsEmptyDaysAndRequestWindows() {
        let range = ServerCalendarRange(start: date("2026-10-25"), end: date("2026-10-24"))
        XCTAssertTrue(range.days.isEmpty)
        XCTAssertTrue(range.requestWindows.isEmpty)
    }

    @MainActor
    func testWeekRetainsSevenMondayToSundayGroupsAndTodayNavigation() {
        let model = ServerWorkspaceCalendarModel()
        model.referenceDate = date("2026-10-23")
        XCTAssertEqual(model.agendaDays.map(\.id), ["2026-10-19", "2026-10-20", "2026-10-21",
            "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
        XCTAssertTrue(model.agendaDays.allSatisfy { $0.events.isEmpty })
        model.navigate(1)
        XCTAssertEqual(model.agendaDays.first?.id, "2026-10-26")
        model.selectToday(date("2026-10-23"))
        XCTAssertEqual(model.agendaDays.first?.id, "2026-10-19")
        model.mode = .day
        XCTAssertEqual(model.agendaDays.map(\.id), ["2026-10-23"])
    }

    @MainActor
    func testSemesterRangeExhaustsWindowsAndDeduplicatesOverlap() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let tokens = MockTokenStore()
        tokens.accessToken = "calendar-test-owner"
        let client = ServerClient(configuration: .init(baseURL: URL(string: "https://calendar.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens))
        let model = ServerWorkspaceCalendarModel(client: client)
        model.referenceDate = date("2024-01-01")
        MockURLProtocol.stubJSON(["subscription": ["sections": [[
            "id": 7, "jwId": 42, "code": "CALC-01", "kind": "regular",
            "semester": ["id": 1, "code": "extended", "nameCn": "Extended semester",
                         "startDate": "2024-01-01T00:00:00+08:00", "endDate": "2025-01-02T00:00:00+08:00"]
        ]]]])
        await model.loadSemesters()
        XCTAssertEqual(model.semesters.count, 1)
        XCTAssertTrue(model.modes.contains(.semester))
        model.mode = .semester
        var windows: [String] = []
        MockURLProtocol.requestHandler = { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let from = items.first { $0.name == "dateFrom" }!.value!
            let to = items.first { $0.name == "dateTo" }!.value!
            windows.append("\(from)/\(to)")
            let event: [String: Any] = ["id": "activity-overlap", "type": "young_event", "title": "Long activity",
                "at": "2024-12-31T09:00:00+08:00", "endsAt": "2025-01-01T18:00:00+08:00",
                "url": "/catalog/young-events/activity-overlap"]
            let body: [String: Any] = ["data": [event],
                "pagination": ["page": 1, "pageSize": 100, "total": 1, "totalPages": 1]]
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: body))
        }
        await model.load()
        XCTAssertEqual(windows, ["2024-01-01/2024-12-31", "2025-01-01/2025-01-02"])
        XCTAssertEqual(model.events.map(\.id), ["activity-overlap"])
        XCTAssertEqual(model.agendaDays.count, 1)
        client.clearTokens()
        XCTAssertTrue(model.semesters.isEmpty)
        XCTAssertFalse(model.modes.contains(.semester))
    }

    @MainActor
    func testActivityOnlyAccountKeepsDayWeekMonthWithoutSemester() async {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let tokens = MockTokenStore()
        tokens.accessToken = "activity-only-owner"
        let client = ServerClient(configuration: .init(baseURL: URL(string: "https://calendar.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens))
        MockURLProtocol.stubJSON(["subscription": ["sections": []]])
        let model = ServerWorkspaceCalendarModel(client: client)
        await model.loadSemesters()
        XCTAssertEqual(model.modes, [.day, .week, .month])
    }
}
